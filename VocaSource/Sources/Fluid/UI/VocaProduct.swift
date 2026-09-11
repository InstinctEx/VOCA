import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Product destinations stay local until VOCA has its own support and release services.
enum VocaProduct {
    static let navigation = Notification.Name("VOCA.productNavigation")
    static let updateMessage = "This is a local VOCA preview. Automatic updates will be available when VOCA’s release channel is ready."
    static let upstreamSource = URL(string: "https://github.com/altic-dev/Fluid-oss")!

    @MainActor static func navigate(_ page: String) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: self.navigation, object: page)
    }

    @MainActor static func showUpdateStatus() {
        let alert = NSAlert()
        alert.messageText = "VOCA Updates"
        alert.informativeText = self.updateMessage
        alert.addButton(withTitle: "What’s New")
        alert.addButton(withTitle: "Done")
        if alert.runModal() == .alertFirstButtonReturn { self.navigate("notes") }
    }

    static func feedbackDraft(_ message: String, version: String) -> String {
        "VOCA feedback\nVersion: \(version)\n\n\(message.trimmingCharacters(in: .whitespacesAndNewlines))\n"
    }
}

struct VocaTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        self.text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(self.text.utf8))
    }
}

struct VocaHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var showCredits = false
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("VOCA Help").font(.title2.bold())
                Spacer()
                Button("Done") { self.dismiss() }.keyboardShortcut(.cancelAction).fluidButton(.secondary)
            }
            helpRow("Speak where you write", "Place your cursor in a text field, then use your dictation shortcut. Finish with the same shortcut to insert your words.", "text.cursor")
            helpRow("Make it sound like you", "Choose a speech model, then add optional Text Enhancement and a Writing Style. Local models stay on your Mac; connected API services process the text you send them.", "waveform")
            helpRow("If your words don’t appear", "Check Microphone and Accessibility access in Settings. Keep the destination field focused while dictating. History keeps completed transcriptions available to copy again.", "keyboard")
            helpRow("Room to think", "Enable Finish after a pause in Dictation settings. Choose your thinking time; speaking resets the countdown. Tap the countdown to keep listening. Automatic finish never sends a message.", "pause.circle")
            helpRow("If cleanup takes too long", "After eight seconds, the clock indicator offers your original words. At thirty seconds VOCA falls back automatically. Quick Controls (⌘K) and Text Enhancement explain the last timing.", "clock")
            DisclosureGroup("License & open-source acknowledgments", isExpanded: self.$showCredits) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("VOCA is a preview; no paid activation is required. A paid download and support offering is planned, with corresponding source and GPL rights preserved. VOCA is based on FluidVoice by Altic and its contributors, with interface and product changes by VOCA. Distributed under GNU GPL version 3. No warranty is provided. You may modify and redistribute it under that license.")
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Link("Original source", destination: VocaProduct.upstreamSource)
                        Button("Read GPL License") {
                            if let url = Bundle.main.url(forResource: "FluidVoice-GPL-3.0", withExtension: "txt") { NSWorkspace.shared.open(url) }
                        }.buttonStyle(.link)
                    }
                }.font(.callout).foregroundStyle(self.theme.palette.secondaryText).padding(.top, 10)
            }
            .animation(.easeInOut(duration: 0.18), value: self.showCredits)
        }
        .padding(28).frame(width: 580)
        .background(self.theme.palette.windowBackground)
        .vocaMotionPolicy()
    }
    private func helpRow(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(self.theme.palette.accent).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(self.theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
