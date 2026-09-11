import AppKit
import Carbon

/// Uses the players' public AppleScript interfaces; never global media-key toggles.
@MainActor
final class MediaPlaybackService {
    static let shared = MediaPlaybackService()
    static let supportedPlayers = ["com.apple.Music", "com.spotify.client"]
    typealias Command = @Sendable (String, String) async -> String?
    private let command: Command
    private let permittedPlayers: () -> [String]
    private var pausedTracks: [String: String] = [:]
    private var generation = 0

    init(command: @escaping Command = MediaPlaybackService.runCommand,
         permittedPlayers: @escaping () -> [String] = MediaPlaybackService.authorizedRunningPlayers) {
        self.command = command
        self.permittedPlayers = permittedPlayers
    }

    static func requestAccess(to bundleID: String) {
        guard supportedPlayers.contains(bundleID),
              !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty else { return }
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleID)
        _ = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
    }

    static func authorizedRunningPlayers() -> [String] {
        supportedPlayers.filter { id in
            guard !NSRunningApplication.runningApplications(withBundleIdentifier: id).isEmpty else { return false }
            let target = NSAppleEventDescriptor(bundleIdentifier: id)
            return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, false) == noErr
        }
    }

    func pauseIfPlaying() async -> Bool {
        generation += 1
        let session = generation
        // Do not carry pause ownership from another recording.
        pausedTracks = [:]
        for player in permittedPlayers() {
            guard let track = await command(player, "pause"), !track.isEmpty else { continue }
            guard generation == session else {
                _ = await command(player, "resume:\(track)")
                return false
            }
            pausedTracks[player] = track
        }
        return !pausedTracks.isEmpty
    }

    func resumeIfWePaused(_ wePaused: Bool) async {
        guard wePaused else { return }
        generation += 1
        let tracks = pausedTracks
        pausedTracks = [:]
        for (player, track) in tracks { _ = await command(player, "resume:\(track)") }
    }

    /// Fixed script + argv, not interpolated source. No transcript, URL or user text
    /// is evaluated. The helper returns only an opaque track ID, never a track title.
    nonisolated static func runCommand(player: String, operation: String) async -> String? {
        guard supportedPlayerID(player) else { return nil }
        return await Task.detached(priority: .utility) {
            let identifier = player == "com.apple.Music" ? "persistent ID" : "id"
            let script = """
            on run argv
                with timeout of 1 seconds
                    if application id "\(player)" is not running then return ""
                    tell application id "\(player)"
                        set mode to item 1 of argv
                        if mode is "pause" then
                            if player state is not playing then return ""
                            set trackID to \(identifier) of current track as text
                            pause
                            if player state is paused then return trackID
                        else
                            set expectedID to item 2 of argv
                            if player state is paused and (\(identifier) of current track as text) is expectedID then play
                        end if
                    end tell
                end timeout
                return ""
            end run
            """
            let parts = operation.split(separator: ":", maxSplits: 1).map(String.init)
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script, parts[0], parts.count > 1 ? parts[1] : ""]
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                // Bound a stuck helper as well as Apple Event reply time.
                let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: timeout)
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                timeout.cancel()
                guard process.terminationStatus == 0 else { return nil }
                return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            } catch { return nil }
        }.value
    }
    nonisolated private static func supportedPlayerID(_ id: String) -> Bool {
        id == "com.apple.Music" || id == "com.spotify.client"
    }
}
