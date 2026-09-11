import AppKit
import UniformTypeIdentifiers

enum TranscriptionFeedbackReporter {
    struct Payload: Encodable {
        let rawText: String
        let processedText: String
        let processingModel: String
        let comments: String
    }

    /// The public VOCA preview has no reporting endpoint. Export only after an explicit save.
    @MainActor static func export(_ payload: Payload) async throws -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "VOCA Example.json"
        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            panel.begin { continuation.resume(returning: $0) }
        }
        guard response == .OK, let url = panel.url else { return false }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: url, options: .atomic)
        return true
    }
}
