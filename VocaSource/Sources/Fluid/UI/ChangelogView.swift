import SwiftUI

/// Release notes describe this VOCA build; never fetch another product’s releases.
struct ChangelogView: View {
    @Environment(\.theme) private var theme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VocaPageHeader(title: "What’s New", subtitle: "A quieter space for your voice.", symbol: "sparkles")
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Text("VOCA Preview").font(.title3.bold())
                        Spacer()
                        Text("September 2026").font(.callout).foregroundStyle(self.theme.palette.secondaryText)
                    }
                    Divider()
                    update("Polish, without the cloud", "VOCA Polish runs Qwen 4B directly on Apple Silicon. Download once, use your writing styles offline, and see real timings in the local sample editor. Pause and resume downloads, or free model memory whenever you need it.", "sparkles")
                    update("Sounds like you", "Twelve writing templates and a personal style made from examples you choose. The examples are analyzed locally; review the suggested habits before saving.", "person.text.rectangle")
                    update("Room to think", "Optional automatic finish waits through a pause, then shows a three-second countdown. Speak again to reset it, or tap the countdown to keep listening. It never submits a message.", "pause.circle")
                    update("No endless refining", "Slow cleanup gets an eight-second warning and an original-words option. A thirty-second limit keeps a slow provider from holding your words indefinitely.", "clock")
                    update("A clearer first step", "The draggable Accessibility guide is back. Detailed diagnostics are now off by default, and delayed results check their destination before inserting.", "checkmark.shield")
                    update("Right beside your words", "Choose a compact cursor pill in Overlay settings. It finds space around the typing cursor, with a screen-edge fallback for apps that do not expose cursor bounds.", "cursorarrow.rays")
                    update("Confidence in every insertion", "Check a destination with a real test insertion. Recover your last words or undo a verified insertion while preserving later appends.", "arrow.uturn.backward")
                    update("Less setup, more writing", "Quick Controls (⌘K), writing templates, a searchable Phrase Library, responsive History, and a local model recommendation and timing check.", "slider.horizontal.3")
                    update("A lighter touch", "Interactive Liquid Glass on navigation controls, short transitions between pages, and gentle changes in status. Motion steps back when Reduce Motion is enabled.", "water.waves")
                    update("Made for your Mac", "Native blue, deep ink surfaces, soft-white light mode, and a cleaner sidebar. The practice editor’s placeholder now follows the same text layout as its cursor.", "macwindow")
                    update("Your voice, your destination", "Dictation opens at the notch with your destination app icon and a live waveform, then contracts when finished.", "waveform")
                    update("The tools you need", "Speech models, local and API text enhancement, writing styles, custom phrases, shortcuts, history, and file transcription remain available.", "slider.horizontal.3")
                }.padding(24).vocaContentSurface()
                Label(VocaProduct.updateMessage, systemImage: "info.circle")
                    .font(.callout).foregroundStyle(self.theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }.frame(maxWidth: 900).padding(32).frame(maxWidth: .infinity)
        }
    }
    private func update(_ title: String, _ detail: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: symbol).font(.title2).foregroundStyle(self.theme.palette.accent).frame(width: 28).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(self.theme.palette.secondaryText).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
