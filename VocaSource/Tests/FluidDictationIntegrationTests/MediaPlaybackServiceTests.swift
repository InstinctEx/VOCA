@testable import FluidVoice_Debug
import XCTest

@MainActor
final class MediaPlaybackServiceTests: XCTestCase {
    func testOnlyAuthorizedPlayersAreQueried() async {
        let controller = PlayerFixture()
        let service = MediaPlaybackService(command: { await controller.run($0, $1) }, permittedPlayers: { [] })
        let paused = await service.pauseIfPlaying()
        XCTAssertFalse(paused)
        let calls = await controller.calls
        XCTAssertTrue(calls.isEmpty)
    }
    func testSuccessfulPauseResumesSameTrackOnlyOnce() async {
        let controller = PlayerFixture(result: "track:123")
        let service = MediaPlaybackService(command: { await controller.run($0, $1) }, permittedPlayers: { ["com.apple.Music"] })
        let paused = await service.pauseIfPlaying()
        XCTAssertTrue(paused)
        await service.resumeIfWePaused(paused)
        await service.resumeIfWePaused(paused)
        let calls = await controller.calls
        XCTAssertEqual(calls, ["com.apple.Music pause", "com.apple.Music resume:track:123"])
    }
    func testFailedPauseNeverResumesPlayer() async {
        let controller = PlayerFixture()
        let service = MediaPlaybackService(command: { await controller.run($0, $1) }, permittedPlayers: { ["com.apple.Music"] })
        let paused = await service.pauseIfPlaying()
        XCTAssertFalse(paused)
        await service.resumeIfWePaused(true)
        let calls = await controller.calls
        XCTAssertEqual(calls, ["com.apple.Music pause"])
    }
    func testBothAuthorizedPlayersAreRemembered() async {
        let controller = PlayerFixture(result: "track")
        let service = MediaPlaybackService(command: { await controller.run($0, $1) }, permittedPlayers: { MediaPlaybackService.supportedPlayers })
        let paused = await service.pauseIfPlaying()
        await service.resumeIfWePaused(paused)
        let calls = await controller.calls
        XCTAssertEqual(Set(calls), ["com.apple.Music pause", "com.spotify.client pause", "com.apple.Music resume:track", "com.spotify.client resume:track"])
    }
    func testUnknownPlayerCannotExecuteScript() async {
        let value = await MediaPlaybackService.runCommand(player: "untrusted\" application", operation: "pause")
        XCTAssertNil(value)
    }
}
private actor PlayerFixture {
    let result: String?
    var calls: [String] = []
    init(result: String? = nil) { self.result = result }
    func run(_ player: String, _ operation: String) -> String? {
        calls.append("\(player) \(operation)")
        return result
    }
}
