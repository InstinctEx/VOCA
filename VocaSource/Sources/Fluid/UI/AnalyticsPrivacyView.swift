import SwiftUI

struct AnalyticsPrivacyView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("Privacy in VOCA").font(.title2.bold())
                Spacer()
                Button("Done") { self.dismiss() }.keyboardShortcut(.cancelAction).fluidButton(.secondary)
            }
            privacy("Usage", "This preview has no analytics service configured. Usage history is stored locally on this Mac.")
            privacy("Dictation", "Local speech models process audio on your Mac. Apple Speech uses the system’s speech services. Choosing a connected text-enhancement provider sends the text required for that request to that provider.")
            privacy("History", "Your history and any saved audio follow your History settings. You can clear history, manage audio retention, and export your data in Settings.")
            privacy("Feedback", "Feedback drafts and example reports are exported locally. Nothing is sent to a support server.")
            Spacer(minLength: 0)
        }.padding(28).background(self.theme.palette.windowBackground)
    }
    private func privacy(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.headline)
            Text(detail).font(.callout).foregroundStyle(self.theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
        }
    }
}
