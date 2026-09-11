import Foundation
import Combine

enum VocaCleanupError: LocalizedError, Equatable {
    case timeout, skipped, busy
    var errorDescription: String? {
        switch self {
        case .timeout: return "AI cleanup took too long. Your original words were used. Try a smaller model, warm up your local model, or switch provider in Quick Controls."
        case .skipped: return "Cleanup skipped. Your original words were used."
        case .busy: return "The previous cleanup is still ending. Your original words were used."
        }
    }
}

/// Resolves once even when a provider ignores cancellation. Late answers cannot insert text.
@MainActor final class VocaCleanupRace<Value> {
    private var continuation: CheckedContinuation<Value, Error>?
    var operation: Task<Void, Never>?
    var watchdog: Task<Void, Never>?
    init(_ continuation: CheckedContinuation<Value, Error>) { self.continuation = continuation }
    func finish(_ result: Result<Value, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        operation?.cancel(); watchdog?.cancel()
        self.operation = nil; self.watchdog = nil
        continuation.resume(with: result)
    }
}

@MainActor final class VocaCleanupMonitor: ObservableObject {
    static let shared = VocaCleanupMonitor()
    @Published private(set) var running = false
    @Published private(set) var slow = false
    @Published private(set) var label = ""
    @Published private(set) var lastResult = "No cleanup timings yet."
    @Published private(set) var lastSeconds: Double = 0
    private var skipAction: (() -> Void)?
    private var activeID: UUID?
    func useOriginal() { skipAction?() }
    func acceptsPreview(_ id: UUID) -> Bool { activeID == id && running }

    func run<Value>(id: UUID, label: String, warningAfter: Double = 8, deadline: Double = 30,
                    operation: @escaping @MainActor () async throws -> Value) async throws -> Value {
        guard !running else { throw VocaCleanupError.busy }
        running = true; slow = false; self.label = label; activeID = id
        let started = ProcessInfo.processInfo.systemUptime
        defer {
            running = false; slow = false; skipAction = nil; activeID = nil
            lastSeconds = ProcessInfo.processInfo.systemUptime - started
        }
        do {
            let value: Value = try await withCheckedThrowingContinuation { continuation in
                let race = VocaCleanupRace<Value>(continuation)
                skipAction = { race.finish(.failure(VocaCleanupError.skipped)) }
                race.operation = Task { @MainActor in
                    do { race.finish(.success(try await operation())) }
                    catch { race.finish(.failure(error)) }
                }
                race.watchdog = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: .seconds(max(0, warningAfter)))
                        self?.slow = true
                        try await Task.sleep(for: .seconds(max(0, deadline - warningAfter)))
                        race.finish(.failure(VocaCleanupError.timeout))
                    } catch { /* The result or user ended this watchdog. */ }
                }
            }
            lastResult = "\(label) finished in \(String(format: "%.1f", ProcessInfo.processInfo.systemUptime - started))s."
            return value
        } catch {
            lastResult = error.localizedDescription
            throw error
        }
    }
}
