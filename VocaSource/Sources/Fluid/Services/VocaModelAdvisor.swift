import Accelerate
import Foundation
import Combine

@MainActor final class VocaModelAdvisor: ObservableObject {
    static let shared = VocaModelAdvisor()
    @Published private(set) var isRunning = false
    @Published private(set) var recommendation: SettingsStore.SpeechModel?
    @Published private(set) var description = "Run a short, local hardware check to find a sensible starting model."
    @Published private(set) var measurement: String?

    nonisolated static func recommend(appleSilicon: Bool, memoryGB: Int, gigaFlops: Double) -> SettingsStore.SpeechModel {
        if memoryGB < 8 || gigaFlops < 8 { return .whisperBase }
        if appleSilicon { return .parakeetTDT }
        return memoryGB >= 16 && gigaFlops >= 30 ? .whisperSmall : .whisperBase
    }

    func run() async {
        guard !self.isRunning else { return }
        self.isRunning = true
        defer { self.isRunning = false }
        self.description = "Measuring this Mac’s local compute performance…"
        let rate = await Task.detached(priority: .utility) {
            let dimension = 768
            let a = [Float](repeating: 0.125, count: dimension * dimension)
            let b = [Float](repeating: 0.25, count: dimension * dimension)
            var result = [Float](repeating: 0, count: dimension * dimension)
            func multiply() {
                cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(dimension), Int32(dimension), Int32(dimension), 1, a, Int32(dimension), b, Int32(dimension), 0, &result, Int32(dimension))
            }
            multiply() // Warm up Accelerate before measuring.
            let start = ProcessInfo.processInfo.systemUptime
            var runs = 0
            repeat { multiply(); runs += 1 } while ProcessInfo.processInfo.systemUptime - start < 1.0
            let elapsed = ProcessInfo.processInfo.systemUptime - start
            return Double(runs) * 2 * pow(Double(dimension), 3) / elapsed / 1_000_000_000
        }.value
        #if arch(arm64)
        let silicon = true
        #else
        let silicon = false
        #endif
        let memoryGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        let model = Self.recommend(appleSilicon: silicon, memoryGB: memoryGB, gigaFlops: rate)
        self.recommendation = model
        self.measurement = "\(memoryGB) GB memory · \(ProcessInfo.processInfo.activeProcessorCount) CPU cores · \(String(format: "%.0f", rate)) GFLOPS measured"
        self.description = model == .parakeetTDT
            ? "Parakeet is a good starting point for fast, multilingual dictation on this Apple silicon Mac."
            : "\(model.displayName) is a lighter starting point for this Mac’s memory and compute performance."
    }
}
