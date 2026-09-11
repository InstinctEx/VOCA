//
//  AISettingsView+SpeechRecognition.swift
//  fluid
//
//  Extracted from AISettingsView.swift to keep view body under lint limit.
//

import SwiftUI

extension VoiceEngineSettingsView {
    // MARK: - Speech Recognition Card

    var speechRecognitionCard: some View {
        let models = self.viewModel.filteredSpeechModels.filter { self.modelLibraryScope != "Downloaded" || $0.isInstalled }.filter {
            self.modelSearch.isEmpty || $0.humanReadableName.localizedCaseInsensitiveContains(self.modelSearch) || self.speechModelSubtitle(for: $0).localizedCaseInsensitiveContains(self.modelSearch) || $0.cardDescription.localizedCaseInsensitiveContains(self.modelSearch)
        }
        return ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VocaPageHeader(title: "Speech Models", subtitle: "Find the right balance of speed, language, and accuracy for your voice.", symbol: "waveform")
                HStack(spacing: 14) {
                    VocaBrandMark(size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current voice engine").font(.caption).foregroundStyle(.secondary)
                        Text(self.speechModelSubtitle(for: self.settings.selectedSpeechModel)).font(.headline)
                    }
                    Spacer()
                    Label(self.viewModel.asr.isAsrReady ? "Ready" : "Selected", systemImage: self.viewModel.asr.isAsrReady ? "checkmark.circle.fill" : "circle")
                        .font(.callout).foregroundStyle(.secondary)
                }.padding(18).vocaContentSurface()
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VocaSectionHeading(title: "Voice library", detail: "\(models.count) available")
                    }
                    Picker("Library", selection: self.$modelLibraryScope) {
                        Text("All models").tag("All models")
                        Text("Downloaded").tag("Downloaded")
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 280)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { self.modelSearchField; self.modelFilters }
                        VStack(spacing: 12) { self.modelSearchField; self.modelFilters }
                    }
                    if models.isEmpty {
                        ContentUnavailableView.search(text: self.modelSearch)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(models) { model in
                                self.speechModelCard(for: model)
                                if model != models.last { Divider().padding(.leading, 64) }
                            }
                        }.vocaContentSurface()
                    }
                    Button("About the selected model", systemImage: "info.circle") { self.showModelDetails = true }
                        .buttonStyle(.borderless).font(.system(size: 12))
                }
                VocaModelRecommendationView(viewModel: self.viewModel)
                DisclosureGroup("Transcription preferences") {
                    self.fillerWordsSection.padding(.top, 14)
                }.font(.system(size: 13, weight: .medium)).padding(20).vocaContentSurface()
            }.frame(maxWidth: 900).padding(32).frame(maxWidth: .infinity)
        }
    }

    private var modelSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(self.theme.palette.secondaryText)
            TextField("Search models", text: self.$modelSearch).textFieldStyle(.plain)
            if !self.modelSearch.isEmpty {
                Button { self.modelSearch = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(self.theme.palette.secondaryText) }
                    .buttonStyle(.plain).accessibilityLabel("Clear model search")
            }
        }.padding(11).vocaContentSurface()
    }

    private var modelFilters: some View {
        HStack(spacing: 10) {
            Picker("Source", selection: self.$viewModel.providerFilter) {
                ForEach(SpeechProviderFilter.allCases) { Text($0.rawValue).tag($0) }
            }.labelsHidden().frame(width: 140)
            Picker("Sort", selection: self.$viewModel.modelSortOption) {
                ForEach(ModelSortOption.allCases) { Text($0.rawValue).tag($0) }
            }.labelsHidden().frame(width: 135)
        }.controlSize(.regular)
    }

    var previewModelTitle: String { self.speechModelSubtitle(for: self.viewModel.previewSpeechModel) }

    var modelStatsPanel: some View {
        let model = self.viewModel.previewSpeechModel
        return VStack(alignment: .leading, spacing: 14) {
            Text(model.cardDescription).foregroundStyle(self.theme.palette.secondaryText)
            HStack(spacing: 18) {
                Label(model.downloadSize, systemImage: "internaldrive")
                if model.requiresAppleSilicon { Label("Apple silicon", systemImage: "cpu") }
            }.font(.caption).foregroundStyle(self.theme.palette.secondaryText)
            if let languages = model.supportedLanguageCodes {
                Text(languages).font(.caption).foregroundStyle(self.theme.palette.secondaryText)
            }
            if let warning = model.memoryWarning {
                Label(warning, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            if model.supportsCustomVocabulary {
                Button("Personalize vocabulary", systemImage: "character.book.closed") {
                    NotificationCenter.default.post(name: .openCustomDictionaryFromVoiceEngine, object: nil)
                }.buttonStyle(.bordered)
            }
        }
    }

    func speechModelCard(for model: SettingsStore.SpeechModel) -> some View {
        let isSelected = self.viewModel.previewSpeechModel == model
        let isConfiguredActive = self.viewModel.isActiveSpeechModel(model)
        let isActive = isConfiguredActive && model.isInstalled && self.viewModel.asr.isAsrReady

        return HStack(alignment: .center, spacing: 14) {
            Button {
                self.viewModel.previewSpeechModel = model
                self.showModelDetails = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "waveform")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(isActive ? Color.fluidGreen : Color.secondary)
                        .frame(width: 38, height: 42)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(self.speechModelSubtitle(for: model)).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                        if self.speechModelSubtitle(for: model) != model.humanReadableName {
                            Text(model.humanReadableName).font(.system(size: 12)).foregroundStyle(self.theme.palette.secondaryText).lineLimit(2)
                        }
                        Text(model.downloadSize).font(.system(size: 11)).foregroundStyle(self.theme.palette.tertiaryText)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("Model details")

            // Action area: Show progress if THIS model is being downloaded
            if self.viewModel.downloadingModel == model {
                // This specific model is currently being downloaded
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if self.viewModel.isCancellingModelDownload {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Cancelling…")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.voiceEngineSecondaryText)
                        } else if self.viewModel.asr.modelPreparationPhase == .downloading,
                                  let progress = self.viewModel.asr.downloadProgress
                        {
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .frame(width: 90)
                            Text("\(Int(progress * 100))%")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.voiceEngineSecondaryText)
                        } else {
                            ProgressView()
                                .controlSize(.mini)
                            Text(self.viewModel.asr.modelPreparationStatusText)
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.voiceEngineSecondaryText)
                        }
                    }

                    Button(self.viewModel.isCancellingModelDownload ? "Cancelling…" : "Cancel") {
                        self.viewModel.cancelSpeechModelDownload()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(self.viewModel.isCancellingModelDownload)
                }
            } else if (self.viewModel.asr.isDownloadingModel
                || self.viewModel.asr.isLoadingModel
                || self.viewModel.asr.isCancellingModelPreparation)
                && isConfiguredActive
                && !self.viewModel.asr.isAsrReady
            {
                // Active model is loading/downloading (for Activate flow)
                HStack(spacing: 8) {
                    VStack(alignment: .trailing, spacing: 4) {
                        if self.viewModel.asr.isCancellingModelPreparation {
                            ProgressView()
                                .controlSize(.mini)
                            Text("Cancelling…")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.voiceEngineSecondaryText)
                        } else if self.viewModel.asr.isDownloadingModel,
                                  self.viewModel.asr.modelPreparationPhase == .downloading,
                                  let progress = self.viewModel.asr.downloadProgress
                        {
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                                .frame(width: 90)
                            Text("\(Int(progress * 100))%")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.voiceEngineSecondaryText)
                        } else {
                            ProgressView()
                                .controlSize(.mini)
                            Text(self.viewModel.asr.modelPreparationStatusText)
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.voiceEngineSecondaryText)
                        }
                    }

                    Button(self.viewModel.asr.isCancellingModelPreparation ? "Cancelling…" : "Cancel") {
                        self.viewModel.cancelActiveModelPreparation()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(self.viewModel.asr.isCancellingModelPreparation)
                }
            } else if model.isInstalled {
                HStack(spacing: 8) {
                    if isActive {
                        self.speechModelLanguagePicker(for: model)
                            .disabled(self.viewModel.areSpeechModelActionsBlocked)

                        Text("Active")
                            .font(self.theme.typography.bodySmallStrong)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.fluidGreen.opacity(0.25)))
                            .foregroundStyle(Color.fluidGreen)
                    } else {
                        Button("Activate") {
                            self.viewModel.activateSpeechModel(model)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(Color.fluidGreen)
                        .fontWeight(.semibold)
                        .shadow(color: Color.fluidGreen.opacity(0.35), radius: 4, x: 0, y: 1)
                        .disabled(self.viewModel.areSpeechModelActionsBlocked)
                    }

                    if !model.usesAppleLogo {
                        if isSelected {
                            Button {
                                self.viewModel.deleteSpeechModel(model)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .disabled(self.viewModel.areSpeechModelActionsBlocked)
                            
                            .opacity(1)
                        }
                    }
                }
            } else {
                ZStack(alignment: .trailing) {
                    if model.requiresExternalArtifacts {
                        HStack(spacing: 8) {
                            if model.externalCoreMLSpec?.sourceURL != nil {
                                Button {
                                    self.viewModel.openExternalModelSource(for: model)
                                } label: {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 14))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(self.voiceEngineTertiaryText)
                                .disabled(self.viewModel.areSpeechModelActionsBlocked)
                            }

                            Button("Download") {
                                self.viewModel.previewSpeechModel = model
                                self.viewModel.downloadSpeechModel(model)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(Color.fluidGreen)
                            .disabled(self.viewModel.areSpeechModelActionsBlocked)
                        }
                        
                        .opacity(1)
                    } else {
                        Text("Not downloaded")
                            .font(self.theme.typography.bodySmall)
                            .foregroundStyle(self.voiceEngineTertiaryText)
                            .hidden()

                        Button("Download") {
                            self.viewModel.previewSpeechModel = model
                            self.viewModel.downloadSpeechModel(model)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .tint(Color.fluidGreen)
                        .disabled(self.viewModel.areSpeechModelActionsBlocked)
                        
                        .opacity(1)
                    }
                }
                .frame(width: model.requiresExternalArtifacts ? 150 : 120, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .background(isSelected ? Color.fluidGreen.opacity(0.045) : Color.clear, in: RoundedRectangle(cornerRadius: 16))
        .opacity(self.viewModel.asr.isRunning ? 0.6 : 1.0)
        .allowsHitTesting(!self.viewModel.asr.isRunning)
    }

    @ViewBuilder
    private func speechModelLanguagePicker(for model: SettingsStore.SpeechModel) -> some View {
        if model.isWhisperModel {
            self.whisperLanguagePickerButton
        } else if model == .cohereTranscribeSixBit {
            Menu {
                ForEach(SettingsStore.CohereLanguage.allCases) { language in
                    Button {
                        guard language != self.settings.selectedCohereLanguage else { return }
                        self.settings.selectedCohereLanguage = language
                    } label: {
                        HStack {
                            Text(language.displayName)
                            if language == self.settings.selectedCohereLanguage {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                self.languageChipLabel(self.settings.selectedCohereLanguage.displayName)
            }
            .buttonStyle(.plain)
        } else if model == .nemotronOffline || model == .nemotronStreaming || model == .nemotronStreaming320 {
            self.nemotronLanguagePickerButton
        }
    }

    private var whisperLanguagePickerButton: some View {
        Button {
            self.whisperLanguageSearchText = ""
            self.isShowingWhisperLanguagePicker.toggle()
        } label: {
            self.languageChipLabel(self.selectedWhisperLanguageName)
        }
        .buttonStyle(.plain)
        .popover(isPresented: self.$isShowingWhisperLanguagePicker, arrowEdge: .bottom) {
            self.whisperLanguagePickerPopover
        }
    }

    private var selectedWhisperLanguageName: String {
        guard let languageCode = self.settings.selectedWhisperLanguageCode,
              let language = VoiceEngineLanguageCatalog.whisperLanguage(forCode: languageCode)
        else {
            return "Automatic"
        }
        return language.displayName
    }

    private var filteredWhisperLanguages: [VoiceEngineLanguage] {
        let query = self.normalizedWhisperLanguageSearchText
        guard !query.isEmpty else { return VoiceEngineLanguageCatalog.whisperLanguages }
        return VoiceEngineLanguageCatalog.whisperLanguages.filter { language in
            language.displayName.lowercased().contains(query) ||
                language.id.lowercased().contains(query) ||
                language.aliases.contains { $0.lowercased().contains(query) }
        }
    }

    private var normalizedWhisperLanguageSearchText: String {
        self.whisperLanguageSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var whisperLanguagePickerPopover: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(self.voiceEngineTertiaryText)
                TextField("Search languages", text: self.$whisperLanguageSearchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if self.normalizedWhisperLanguageSearchText.isEmpty ||
                        "automatic".contains(self.normalizedWhisperLanguageSearchText)
                    {
                        Button {
                            self.settings.selectedWhisperLanguageCode = nil
                            self.isShowingWhisperLanguagePicker = false
                        } label: {
                            self.whisperLanguagePickerRow(
                                title: "Automatic",
                                isSelected: self.settings.selectedWhisperLanguageCode == nil
                            )
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.vertical, 4)
                    }

                    ForEach(self.filteredWhisperLanguages) { language in
                        let languageCode = VoiceEngineLanguageCatalog.whisperLanguageCode(for: language.id)
                        Button {
                            self.settings.selectedWhisperLanguageCode = languageCode
                            self.isShowingWhisperLanguagePicker = false
                        } label: {
                            self.whisperLanguagePickerRow(
                                title: language.displayName,
                                isSelected: languageCode == self.settings.selectedWhisperLanguageCode
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 280, height: 420)
    }

    private func whisperLanguagePickerRow(title: String, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(.primary)
            Spacer(minLength: 12)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(self.theme.palette.accent)
            }
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    private func languageChipLabel(_ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "globe")
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(self.theme.palette.accent)
            Text(title)
                .lineLimit(1)
                .fontWeight(.semibold)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(self.voiceEngineTertiaryText)
        }
        .font(self.theme.typography.bodySmallStrong)
        .frame(minHeight: 24)
        .padding(.horizontal, 9)
        .background(
            Capsule()
                .fill(self.theme.palette.accent.opacity(0.10))
                .overlay(
                    Capsule()
                        .stroke(self.theme.palette.accent.opacity(0.28), lineWidth: 1)
                )
        )
    }

    private func speechModelSubtitle(for model: SettingsStore.SpeechModel) -> String {
        switch model {
        case .nemotronStreaming, .nemotronStreaming320:
            return "Nemotron Speech 3.5 - Streaming Capable"
        default:
            return model.displayName
        }
    }

    private var nemotronLanguagePickerButton: some View {
        Button {
            self.isShowingNemotronLanguagePicker.toggle()
        } label: {
            self.languageChipLabel(self.settings.selectedNemotronLanguage.compactDisplayName)
        }
        .buttonStyle(.plain)
        .popover(isPresented: self.$isShowingNemotronLanguagePicker, arrowEdge: .bottom) {
            self.nemotronLanguagePickerPopover
        }
    }

    private var nemotronLanguagePickerPopover: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(SettingsStore.NemotronLanguage.allCases) { language in
                    Button {
                        self.settings.selectedNemotronLanguage = language
                        self.isShowingNemotronLanguagePicker = false
                    } label: {
                        HStack(spacing: 8) {
                            Text(language.displayName)
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 12)
                            if language == self.settings.selectedNemotronLanguage {
                                Image(systemName: "checkmark")
                                    .font(self.theme.typography.bodySmall)
                                    .foregroundStyle(self.theme.palette.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(width: 260, height: 532)
    }

    var modelStatusView: some View {
        HStack(spacing: 12) {
            if (self.viewModel.asr.isDownloadingModel || self.viewModel.asr.isLoadingModel) && !self.viewModel.asr.isAsrReady {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small).fixedSize()
                    Text(self.viewModel.asr.isLoadingModel ? "Loading model…" : "Downloading model…")
                        .font(self.theme.typography.bodySmall)
                        .foregroundStyle(self.voiceEngineSecondaryText)
                }
            } else if self.viewModel.asr.isAsrReady {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.fluidGreen).font(self.theme.typography.bodySmall)
                Text("Ready").font(self.theme.typography.bodySmall).foregroundStyle(self.voiceEngineSecondaryText)

                Button(action: { Task { await self.viewModel.deleteModels() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else if self.viewModel.asr.modelsExistOnDisk {
                Image(systemName: "doc.fill").foregroundStyle(self.theme.palette.accent).font(self.theme.typography.bodySmall)
                Text("Cached")
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(self.voiceEngineSecondaryText)

                Button(action: { Task { await self.viewModel.deleteModels() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 8) {
                    if self.settings.selectedSpeechModel.requiresExternalArtifacts,
                       self.settings.selectedSpeechModel.externalCoreMLSpec?.sourceURL != nil
                    {
                        Button(action: { self.viewModel.openExternalModelSource(for: self.settings.selectedSpeechModel) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.right.square")
                                Text("Hugging Face")
                            }
                            .font(self.theme.typography.bodySmall)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(self.theme.palette.accent)
                    }

                    Button(action: { Task { await self.viewModel.downloadModels() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Download")
                        }
                        .font(self.theme.typography.bodySmall)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.fluidGreen)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(self.theme.palette.cardBackground.opacity(0.8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(self.theme.palette.cardBorder.opacity(0.5), lineWidth: 1)))
    }

    var fillerWordsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove Filler Words")
                        .font(self.theme.typography.bodyStrong)
                        .foregroundStyle(self.voiceEngineTitleText)
                    Text("Automatically remove filler sounds like 'um', 'uh', 'er' from transcriptions")
                        .font(self.theme.typography.bodySmall)
                        .foregroundStyle(self.voiceEngineSecondaryText)
                }
                Spacer()
                Toggle("", isOn: self.$viewModel.removeFillerWordsEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: self.viewModel.removeFillerWordsEnabled) { _, newValue in
                        self.settings.removeFillerWordsEnabled = newValue
                    }
            }

            if self.viewModel.removeFillerWordsEnabled {
                FillerWordsEditor()
            }
        }
    }

    // MARK: - Speech Model Logo View

    private func speechModelLogoView(for model: SettingsStore.SpeechModel) -> some View {
        let bgColor = self.speechModelBackgroundColor(for: model)
        let imageName = self.speechModelImageName(for: model)
        let isNvidia = model.brandName.lowercased().contains("nvidia")

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(bgColor)

            if model.usesAppleLogo {
                Image(systemName: "apple.logo")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
            } else if let imageName {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    // NVIDIA logo larger to fill more of the container
                    .frame(width: isNvidia ? 24 : 18, height: isNvidia ? 24 : 18)
            } else {
                Text(String(model.brandName.prefix(2)).uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(self.theme.palette.primaryText)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func speechModelBackgroundColor(for model: SettingsStore.SpeechModel) -> Color {
        let brand = model.brandName.lowercased()

        // Both NVIDIA and OpenAI use white/light gray bg (transparent logos)
        if brand.contains("nvidia") || brand.contains("openai") || brand.contains("whisper") {
            return Color(red: 0.97, green: 0.97, blue: 0.97)
        }
        if brand.contains("apple") || model.usesAppleLogo {
            return self.theme.palette.cardBackground.opacity(0.9)
        }
        return Color(hex: model.brandColorHex)?.opacity(0.2) ?? self.theme.palette.cardBackground
    }

    private func speechModelImageName(for model: SettingsStore.SpeechModel) -> String? {
        let brand = model.brandName.lowercased()

        if brand.contains("nvidia") {
            return "Provider_NVIDIA"
        }
        if brand.contains("cohere") {
            return "Provider_Cohere"
        }
        if brand.contains("openai") || brand.contains("whisper") {
            return "Provider_OpenAI"
        }
        return nil
    }
}

extension Notification.Name {
    static let openCustomDictionaryFromVoiceEngine = Notification.Name("OpenCustomDictionaryFromVoiceEngine")
}
