import SwiftUI

struct VoiceEngineSettingsView: View {
    @ObservedObject var viewModel: VoiceEngineSettingsViewModel
    @ObservedObject var settings: SettingsStore
    @Environment(\.colorScheme) var colorScheme
    @State var isShowingNemotronLanguagePicker = false
    @State var isShowingWhisperLanguagePicker = false
    @State var whisperLanguageSearchText = ""
    @State var modelSearch = ""
    @State var showModelDetails = false
    let theme: AppTheme

    var voiceEngineTitleText: Color {
        Color(nsColor: .labelColor)
    }

    var voiceEngineSecondaryText: Color {
        self.colorScheme == .light ? Color(nsColor: .labelColor).opacity(0.90) : self.theme.palette.primaryText.opacity(0.82)
    }

    var voiceEngineTertiaryText: Color {
        self.colorScheme == .light ? Color(nsColor: .labelColor).opacity(0.85) : self.theme.palette.secondaryText
    }

    var body: some View {
        self.speechRecognitionCard
            .sheet(isPresented: self.$showModelDetails) {
                VStack(alignment: .leading, spacing: 24) {
                    Text(self.previewModelTitle).font(.system(size: 23, weight: .bold))
                    self.modelStatsPanel
                    HStack { Spacer(); Button("Done") { self.showModelDetails = false }.keyboardShortcut(.defaultAction).fluidButton(.primary, size: .small) }
                }.padding(28).frame(width: 460)
            }
            .onAppear { self.viewModel.onAppear() }
            .onChange(of: self.settings.selectedSpeechModel) { _, newValue in
                self.viewModel.handleSelectedSpeechModelChange(newValue)
            }
    }
}
