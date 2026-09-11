import AppKit
import Combine

/// Deliberately a pause heuristic, never a claim to know the speaker's intent.
struct VocaPauseDetector {
    var lastSpeech: TimeInterval?
    var lastFrame: TimeInterval?
    var speechDuration: TimeInterval = 0
    var paused = false

    mutating func hear(level: Double, at now: TimeInterval) {
        let delta = min(0.15, max(0, now - (lastFrame ?? now)))
        lastFrame = now
        if level >= 0.12 {
            speechDuration += delta
            lastSpeech = now
        }
    }

    func remaining(at now: TimeInterval, pause: Double, text: String) -> Int? {
        guard !paused, speechDuration >= 0.35, let lastSpeech, let lastFrame,
              now - lastFrame < 0.8 else { return nil }
        let tail = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lastWord = tail.split(whereSeparator: { !$0.isLetter }).last.map(String.init) ?? ""
        let unfinished = tail.hasSuffix(",") || ["and", "but", "because", "so", "if", "or", "then"].contains(lastWord)
        let wait = unfinished ? max(pause, 20) : pause
        let quiet = now - lastSpeech
        guard quiet >= wait else { return nil }
        return max(0, Int(ceil(wait + 3 - quiet)))
    }
}

@MainActor final class VocaAutoFinish: ObservableObject {
    static let shared = VocaAutoFinish()
    @Published private(set) var countdown: Int?
    @Published private(set) var suspended = false
    private var detector = VocaPauseDetector()
    private var audio: AnyCancellable?
    private var timer: AnyCancellable?

    func start(audio publisher: AnyPublisher<CGFloat, Never>, eligible: @escaping () -> Bool,
               text: @escaping () -> String, finish: @escaping () -> Void) {
        stop()
        guard UserDefaults.standard.bool(forKey: "voca.autoFinish.enabled"), eligible() else { return }
        audio = publisher.sink { [weak self] level in
            self?.detector.hear(level: Double(level), at: ProcessInfo.processInfo.systemUptime)
        }
        timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            guard eligible(), UserDefaults.standard.bool(forKey: "voca.autoFinish.enabled") else { self.stop(); return }
            let stored = UserDefaults.standard.double(forKey: "voca.autoFinish.pause")
            let pause = [3.0, 7.0, 12.0].contains(stored) ? stored : 12
            let next = self.detector.remaining(at: ProcessInfo.processInfo.systemUptime, pause: pause, text: text())
            if next != self.countdown { self.countdown = next }
            if next == 0 { self.stop(); finish() }
        }
    }
    func keepListening() { detector.paused = true; countdown = nil; suspended = true }
    func stop() { audio?.cancel(); timer?.cancel(); audio = nil; timer = nil; countdown = nil; suspended = false; detector = VocaPauseDetector() }
}
