import SwiftUI
import UniformTypeIdentifiers

struct FeedbackView: View {
    @Environment(\.theme) private var theme
    @AppStorage("vocaFeedbackDraft") private var feedback = ""
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var status = ""
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VocaPageHeader(title: "Feedback", subtitle: "A thought, an idea, something we can improve.", symbol: "bubble.left")
                VStack(alignment: .leading, spacing: 18) {
                    Text("What’s on your mind?").font(.headline)
                    Text("Describe what happened and what you expected. Your draft stays on this Mac. VOCA’s support channel is not connected yet; export a copy to share yourself.")
                        .font(.callout).foregroundStyle(self.theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
                    TextEditor(text: self.$feedback)
                        .font(.body).scrollContentBackground(.hidden).frame(minHeight: 180)
                        .padding(10).background(self.theme.palette.windowBackground, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Feedback draft")
                    HStack {
                        Text(self.status).font(.caption).foregroundStyle(self.theme.palette.secondaryText).contentTransition(.opacity)
                        Spacer()
                        Button("Export Feedback…", systemImage: "square.and.arrow.up") { self.isExporting = true }
                            .fluidButton(.primary).disabled(self.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(24).vocaContentSurface()
                Text("Only your message and the app version are included. No logs, recordings, API keys, or account details are added.")
                    .font(.callout).foregroundStyle(self.theme.palette.secondaryText)
            }.frame(maxWidth: 900).padding(32).frame(maxWidth: .infinity)
        }
        .fileExporter(isPresented: self.$isExporting,
                      document: VocaTextDocument(text: VocaProduct.feedbackDraft(self.feedback, version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Preview")),
                      contentType: .plainText, defaultFilename: "VOCA Feedback.txt") { result in
            switch result {
            case .success: self.status = "Feedback exported."
            case .failure(let error): self.exportError = error.localizedDescription
            }
        }
        .alert("Export failed", isPresented: Binding(get: { self.exportError != nil }, set: { if !$0 { self.exportError = nil } })) {
            Button("OK") { self.exportError = nil }
        } message: { Text(self.exportError ?? "") }
    }
}
