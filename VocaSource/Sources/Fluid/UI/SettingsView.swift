//
//  SettingsView.swift
//  fluid
//
//  App preferences and audio device settings
//

import AppKit
import AVFoundation
import PromiseKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    private struct ShortcutRowContent {
        let icon: String
        let iconColor: Color
        let title: String
        let description: String
    }

    @EnvironmentObject var appServices: AppServices
    private var asr: ASRService {
        self.appServices.asr
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @ObservedObject private var settings = SettingsStore.shared
    let selectedSection: SettingsSection
    let searchResults: [SettingsSearchResult]
    let searchScrollRequest: Int
    @ObservedObject var microphonePreferenceCoordinator: MicrophonePreferenceCoordinator
    @Binding var appear: Bool
    @Binding var visualizerNoiseThreshold: Double
    @Binding var selectedInputUID: String
    @Binding var selectedOutputUID: String
    @Binding var inputDevices: [AudioDevice.Device]
    @Binding var outputDevices: [AudioDevice.Device]
    @Binding var accessibilityEnabled: Bool
    @Binding var primaryDictationShortcuts: [HotkeyShortcut]
    @Binding var activeShortcutRecordingTarget: ShortcutRecordingTarget?
    @Binding var shortcutRecordingMessage: String?
    @Binding var commandModeShortcut: HotkeyShortcut?
    @Binding var rewriteShortcut: HotkeyShortcut
    @Binding var cancelRecordingShortcut: HotkeyShortcut
    @Binding var pasteLastTranscriptionShortcut: HotkeyShortcut?
    @Binding var commandModeShortcutEnabled: Bool
    @Binding var rewriteShortcutEnabled: Bool
    @Binding var pasteLastTranscriptionShortcutEnabled: Bool
    @Binding var hotkeyManagerInitialized: Bool
    @Binding var hotkeyMode: HotkeyActivationMode
    @Binding var enableStreamingPreview: Bool
    @Binding var copyToClipboard: Bool

    // CRITICAL FIX: Cache default device names to avoid CoreAudio calls during view body evaluation.
    // Querying AudioDevice.getDefaultInputDevice() in the view body triggers HALSystem::InitializeShell()
    // which races with SwiftUI's AttributeGraph metadata processing and causes EXC_BAD_ACCESS crashes.
    @State private var cachedDefaultInputUID: String = ""
    @State private var cachedDefaultOutputName: String = ""

    // Detailed analytics consent UI state (default ON; daily activity remains enabled)
    @State private var shareDetailedAnalytics: Bool = SettingsStore.shared.shareDetailedAnalytics
    @State private var showAnalyticsPrivacy: Bool = false
    @State private var pendingDetailedAnalyticsValue: Bool? = nil
    @State private var showDetailedAnalyticsConfirmation: Bool = false
    @State private var rollbackVersion: String = ""
    @State private var isRollingBack: Bool = false
    @State private var audioHistoryBudgetText: String = Self.audioBudgetText(for: SettingsStore.shared.audioHistoryBudgetGB)
    @State private var audioHistoryUsageBytes: Int64 = 0
    @State private var draggedMicrophoneUID: String?
    @State private var hoveredMicrophoneUID: String?
    @State private var searchScrollCoordinator = SettingsSearchScrollCoordinator()

    let hotkeyManager: GlobalHotkeyManager?
    let menuBarManager: MenuBarManager
    let startRecording: () -> Void
    let refreshDevices: () -> Void
    let openAccessibilitySettings: () -> Void
    let restartApp: () -> Void
    let revealAppInFinder: () -> Void
    let openApplicationsFolder: () -> Void

    private func isRecording(_ target: ShortcutRecordingTarget) -> Bool {
        self.activeShortcutRecordingTarget == target
    }

    private var detailedAnalyticsToggleBinding: Binding<Bool> {
        Binding(
            get: {
                AnalyticsConfig.fromBundle().isConfigured && (self.pendingDetailedAnalyticsValue ?? self.shareDetailedAnalytics)
            },
            set: { newValue in
                // User is trying to turn OFF → ask first
                if self.shareDetailedAnalytics, !newValue {
                    self.pendingDetailedAnalyticsValue = false
                    self.showDetailedAnalyticsConfirmation = true

                    return
                }

                // Normal ON path
                self.shareDetailedAnalytics = newValue
                self.applyAnalyticsConsentChange(newValue)
            }
        )
    }

    private var detailedAnalyticsConfirmationBinding: Binding<Bool> {
        Binding(
            get: { self.showDetailedAnalyticsConfirmation },
            set: { newValue in
                // Only open modal if we have a pending value
                if newValue {
                    if self.pendingDetailedAnalyticsValue != nil {
                        self.showDetailedAnalyticsConfirmation = true
                    }
                } else {
                    // Closing the modal: reset pending state
                    self.showDetailedAnalyticsConfirmation = false
                    self.pendingDetailedAnalyticsValue = nil
                }
            }
        )
    }

    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
    }

    private var appDisplayName: String {
        Bundle.main.fluidAppDisplayName
    }

    private var launchAtStartupBinding: Binding<Bool> {
        Binding(
            get: { self.settings.launchAtStartupEnabled },
            set: { self.settings.setLaunchAtStartup($0) }
        )
    }

    private func dictationPromptSelectionBinding(for slot: SettingsStore.DictationShortcutSlot) -> Binding<String> {
        Binding(
            get: {
                switch self.settings.dictationPromptSelection(for: slot) {
                case .off:
                    return "__OFF__"
                case .default:
                    return "__DEFAULT__"
                case .privateAI:
                    return PrivateAIProviderPromptFormat.promptSelectionID
                case let .profile(id):
                    return id
                }
            },
            set: { newValue in
                switch newValue {
                case "__OFF__":
                    self.settings.setDictationPromptSelection(.off, for: slot)
                case "__DEFAULT__":
                    self.settings.setDictationPromptSelection(.default, for: slot)
                case PrivateAIProviderPromptFormat.promptSelectionID:
                    guard PrivateAIProviderPromptFormat.isAvailable(settings: self.settings) else { return }
                    self.settings.setDictationPromptSelection(.privateAI, for: slot)
                default:
                    self.settings.setDictationPromptSelection(.profile(newValue), for: slot)
                }
            }
        )
    }

    @ViewBuilder
    private func dictationPromptPicker(for slot: SettingsStore.DictationShortcutSlot) -> some View {
        let profiles = self.settings.promptProfiles(for: .dictate)
        let privateAIAvailable = PrivateAIProviderPromptFormat.isAvailable(settings: self.settings)
        HStack {
            Text("AI Prompt")
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 30)
            Spacer()
            Picker("", selection: self.dictationPromptSelectionBinding(for: slot)) {
                Section("ON-DEVICE") {
                    Text("Fast — No cleanup").tag("__OFF__")
                    if PrivateFeatures.privateAIProvider {
                        Text("Cleanup — Fluid-1")
                            .tag(PrivateAIProviderPromptFormat.promptSelectionID)
                            .disabled(!privateAIAvailable)
                    }
                }
                Section("EXTERNAL") {
                    Text("Cleanup").tag("__DEFAULT__")
                    ForEach(profiles) { profile in
                        Text(profile.name.isEmpty ? "Untitled" : profile.name)
                            .tag(profile.id)
                    }
                }
            }
            .frame(width: 220)
        }
        .padding(.bottom, 4)
    }

    var body: some View {
        SettingsPersistentScrollView(
            theme: self.theme,
            colorScheme: self.colorScheme,
            searchScrollCoordinator: self.searchScrollCoordinator,
            searchScrollTarget: self.selectedSectionSearchResults.first?.target,
            searchScrollRequest: self.searchScrollRequest
        ) {
            VStack(spacing: 16) {
                VocaPageHeader(title: self.selectedSection.title, subtitle: self.sectionSubtitle, symbol: self.selectedSection.systemImage)
                    .settingsSearchTarget(self.selectedSection.searchTarget)
                if self.selectedSection == .dictation {
                    self.insertionSetupSummary
                }

                // App Settings Card
                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        // Section header
                        Label("Startup & appearance", systemImage: "macbook")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        VStack(spacing: 16) {
                            // Launch at startup
                            self.settingsToggleRow(
                                title: "Launch at startup",
                                description: "Automatically start VOCA when you log in",
                                errorMessage: self.settings.launchAtStartupErrorMessage,
                                isOn: self.launchAtStartupBinding
                            )
                            .settingsSearchTarget(.launchAtStartup)
                            Divider().opacity(0.2)

                            // Show window when launched at login
                            self.settingsToggleRow(
                                title: "Show window when launched at login",
                                description: "When off, VOCA starts silently in the menu bar at login. Opening the app yourself always shows the window.",
                                isOn: Binding(
                                    get: { SettingsStore.shared.showMainWindowAtLoginLaunch },
                                    set: { SettingsStore.shared.showMainWindowAtLoginLaunch = $0 }
                                )
                            )
                            .settingsSearchTarget(.showWindowAtLogin)
                            Divider().opacity(0.2)

                            // Hide from Dock & App Switcher
                            self.settingsToggleRow(
                                title: "Hide from Dock & App Switcher",
                                description: "Keep VOCA in the menu bar only (hides Dock icon and Cmd+Tab entry)",
                                footnote: "Note: May require app restart to take effect.",
                                isOn: Binding(
                                    get: { SettingsStore.shared.hideFromDockAndAppSwitcher },
                                    set: { SettingsStore.shared.hideFromDockAndAppSwitcher = $0 }
                                )
                            )
                            .settingsSearchTarget(.dockVisibility)
                            Divider().opacity(0.2)

                            // Accent Color
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Accent Color")
                                            .font(self.theme.typography.bodyStrong)
                                            .foregroundStyle(self.settingsTitleText)
                                        Text("Blue adapts to your Mac’s appearance and contrast settings.")
                                            .font(self.theme.typography.bodySmall)
                                            .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    HStack(spacing: 10) {
                                        ForEach(SettingsStore.AccentColorOption.allCases) { option in
                                            let isSelected = self.settings.accentColorOption == option
                                            Button {
                                                self.settings.accentColorOption = option
                                            } label: {
                                                Circle()
                                                    .fill(option.color)
                                                    .frame(width: 16, height: 16)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(
                                                                isSelected ? self.theme.palette.accent : self.theme.palette.cardBorder.opacity(0.5),
                                                                lineWidth: isSelected ? 2 : 1
                                                            )
                                                    )
                                                    .padding(4)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(option.rawValue)
                                            .help(option.rawValue)
                                        }
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(self.theme.palette.contentBackground)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(self.theme.palette.cardBorder.opacity(0.4), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            .settingsSearchTarget(.accentColor)
                            Divider().opacity(0.2)

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Transcription Sounds")
                                        .font(self.theme.typography.bodyStrong)
                                        .foregroundStyle(self.settingsTitleText)
                                    Text("Choose the sound cue for recording. Some cues include an end sound.")
                                        .font(self.theme.typography.bodySmall)
                                        .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Picker("", selection: Binding(
                                    get: { SettingsStore.shared.transcriptionStartSound },
                                    set: { newValue in
                                        SettingsStore.shared.transcriptionStartSound = newValue
                                        TranscriptionSoundPlayer.shared.playPreview(sound: newValue)
                                    }
                                )) {
                                    ForEach(SettingsStore.TranscriptionStartSound.allCases) { option in
                                        Text(option.displayName).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 170, alignment: .trailing)
                            }
                            .settingsSearchTarget(.transcriptionSounds)

                            if SettingsStore.shared.transcriptionStartSound != .none {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Volume")
                                            .font(self.theme.typography.bodyStrong)
                                            .foregroundStyle(self.settingsTitleText)
                                        Text("Adjust the recording sound cue volume.")
                                            .font(self.theme.typography.bodySmall)
                                            .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    Slider(
                                        value: Binding(
                                            get: { Double(SettingsStore.shared.transcriptionSoundVolume) },
                                            set: { SettingsStore.shared.transcriptionSoundVolume = Float($0) }
                                        ),
                                        in: 0...1,
                                        step: 0.05
                                    ) { editing in
                                        if !editing {
                                            TranscriptionSoundPlayer.shared.playPreviewAtVolume(
                                                SettingsStore.shared.transcriptionSoundVolume
                                            )
                                        }
                                    }
                                    .frame(width: 150)
                                }

                                self.settingsToggleRow(
                                    title: "Independent Volume",
                                    description: "Sound volume stays constant regardless of system volume. Mute is still respected.",
                                    footnote: "Temporarily changes system volume during playback, which may briefly affect other audio.",
                                    isOn: Binding(
                                        get: { SettingsStore.shared.transcriptionSoundIndependentVolume },
                                        set: { SettingsStore.shared.transcriptionSoundIndependentVolume = $0 }
                                    )
                                )
                            }

                            Divider().opacity(0.2)

                            VocaSettingsDisclosure(title: "Version & updates") {
                                VStack(alignment: .leading, spacing: 14) {
                            // Automatic Updates
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Automatic Updates")
                                            .font(self.theme.typography.bodyStrong)
                                            .foregroundStyle(self.settingsTitleText)
                                        Text("VOCA’s update channel is not configured yet")
                                            .font(self.theme.typography.bodySmall)
                                            .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { false },
                                        set: { _ in }
                                    ))
                                    .disabled(true)
                                    .toggleStyle(.switch)
                                    .tint(self.theme.palette.accent)
                                    .labelsHidden()
                                }

                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Beta Releases")
                                            .font(self.theme.typography.bodyStrong)
                                            .foregroundStyle(self.settingsTitleText)
                                        Text("Available when VOCA’s release channel is ready")
                                            .font(self.theme.typography.bodySmall)
                                            .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    Toggle("", isOn: Binding(
                                        get: { SettingsStore.shared.betaReleasesEnabled },
                                        set: { SettingsStore.shared.betaReleasesEnabled = $0 }
                                    ))
                                    .disabled(true)
                                    .toggleStyle(.switch)
                                    .tint(self.theme.palette.accent)
                                    .labelsHidden()
                                }

                                if SettingsStore.shared.betaReleasesEnabled {
                                    Text("Your beta preference is saved for the future release channel.")
                                        .font(.caption)
                                        .foregroundStyle(self.theme.palette.warning)
                                }

                                if let lastCheck = SettingsStore.shared.lastUpdateCheckDate {
                                    Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                        .font(self.theme.typography.bodySmall)
                                        .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Text("Current version: \(self.currentAppVersion)")
                                    .font(self.theme.typography.bodySmall)
                                    .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                            }
                            .settingsSearchTarget(.automaticUpdates)

                            // Update Buttons
                            HStack(spacing: 10) {
                                Button("Update Status") { VocaProduct.showUpdateStatus() }
                                    .fluidButton(.secondary)
                                Button("What’s New") { VocaProduct.navigate("notes") }
                                    .fluidButton(.secondary)
                            }
                            DisclosureGroup("Previous versions") {
                            HStack(spacing: 10) {
                                Button(self.rollbackVersion.isEmpty ? "Rollback" : "Rollback to \(self.rollbackVersion)") {
                                    guard !self.isRollingBack else { return }

                                    let infoText = self.rollbackVersion.isEmpty ? "your previously installed version" : self.rollbackVersion
                                    let targetVersion = self.rollbackVersion
                                    let confirm = NSAlert()
                                    confirm.messageText = "Rollback to \(infoText)?"
                                    confirm.informativeText = "This will restore a previous app version and relaunch VOCA."
                                    confirm.alertStyle = .warning
                                    confirm.addButton(withTitle: "Rollback")
                                    confirm.addButton(withTitle: "Cancel")

                                    guard confirm.runModal() == .alertFirstButtonReturn else { return }

                                    self.isRollingBack = true
                                    Task {
                                        defer {
                                            Task { @MainActor in
                                                self.isRollingBack = false
                                            }
                                        }

                                        do {
                                            try await SimpleUpdater.shared.rollbackToLatestBackup()
                                            await MainActor.run {
                                                let success = NSAlert()
                                                success.messageText = "Rollback Successful"
                                                success.informativeText = "Rolled back to \(targetVersion). VOCA will relaunch shortly."
                                                success.alertStyle = .informational
                                                success.addButton(withTitle: "Report Bug")
                                                success.addButton(withTitle: "OK")
                                                let response = success.runModal()
                                                if response == .alertFirstButtonReturn {
                                                    self.openIssueReportingPage()
                                                }
                                            }
                                        } catch {
                                            await MainActor.run {
                                                let fail = NSAlert()
                                                fail.messageText = "Rollback Failed"
                                                fail.informativeText = error.localizedDescription
                                                fail.alertStyle = .critical
                                                fail.addButton(withTitle: "OK")
                                                fail.runModal()
                                                self.refreshRollbackState()
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                .disabled(self.rollbackVersion.isEmpty || self.isRollingBack)
                                .opacity(self.isRollingBack ? 0.7 : 1.0)

                                Button("Get Previous Builds") {
                                    self.openPreviousBuildPicker()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                            .padding(.top, 12)

                            if self.rollbackVersion.isEmpty {
                                Text("No rollback backup found.")
                                    .font(self.theme.typography.bodySmall)
                                    .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text("Rollback target: \(self.rollbackVersion)")
                                    .font(self.theme.typography.bodySmall)
                                    .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                            }
                            }
                                }
                            }
                        }
                    }
                    .padding(16)
                }
                .shownInSettingsSection(.general, selectedSection: self.selectedSection)

                VocaAutoFinishSettings().shownInSettingsSection(.dictation, selectedSection: self.selectedSection)

                // Global Hotkey Card
                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Label("Keyboard & insertion", systemImage: "keyboard")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            if self.accessibilityEnabled {
                                if self.isRecordingAnyShortcut {
                                    Text("Recording…")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                } else if self.hotkeyManagerInitialized {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.fluidGreen)
                                            .font(.caption)
                                        Text("Active")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(self.settingsSecondaryText)
                                        Button {
                                            NotificationCenter.default.post(name: Notification.Name("voca.restartHotkeyListener"), object: nil)
                                        } label: { Image(systemName: "arrow.clockwise") }
                                            .buttonStyle(.borderless)
                                            .help("Restart keyboard listener")
                                            .accessibilityLabel("Restart keyboard listener")
                                    }
                                } else {
                                    Text("Listener unavailable")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(self.settingsSecondaryText)
                                }
                            }
                        }
                        .settingsSearchTarget(.globalHotkey)

                        if self.accessibilityEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                if self.isRecordingAnyShortcut {
                                    HStack(spacing: 8) {
                                        Image(systemName: "hand.point.up.left.fill")
                                            .foregroundStyle(.orange)
                                        Text("Press your new hotkey combination now…")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                } else if !self.hotkeyManagerInitialized {
                                    HStack(spacing: 8) {
                                        Text("macOS has not enabled the keyboard listener. Check Accessibility and Input Monitoring for this VOCA build.")
                                            .font(.caption)
                                            .foregroundStyle(self.settingsSecondaryText)
                                        Button("Restart listener") {
                                            NotificationCenter.default.post(name: Notification.Name("voca.restartHotkeyListener"), object: nil)
                                        }.buttonStyle(.borderless)
                                    }
                                }

                                // MARK: - Shortcuts Section

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Shortcuts")
                                        .font(self.theme.typography.bodySmallStrong)
                                        .foregroundStyle(self.settingsTitleText)

                                    Text("Primary dictation can use a keyboard shortcut or allowed mouse button. Changes usually apply immediately.")
                                        .font(.caption)
                                        .foregroundStyle(self.settingsTertiaryText)

                                    self.primaryDictationShortcutsList()
                                        .settingsSearchTarget(.primaryDictationShortcuts)
                                    self.dictationPromptPicker(for: .primary)
                                    Divider().opacity(0.2).padding(.vertical, 4)

                                    self.shortcutRow(
                                        content: .init(
                                            icon: "terminal.fill",
                                            iconColor: .secondary,
                                            title: "Command Mode",
                                            description: "Execute voice commands"
                                        ),
                                        shortcut: self.commandModeShortcut,
                                        isRecording: self.isRecording(.command),
                                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                                        recordingMessage: self.isRecording(.command) ? self.shortcutRecordingMessage : nil,
                                        isEnabled: self.$commandModeShortcutEnabled,
                                        requiresShortcutToEnable: true,
                                        onChangePressed: {
                                            DebugLogger.shared.debug("Starting to record new command mode shortcut", source: "SettingsView")
                                            self.shortcutRecordingMessage = nil
                                            self.activeShortcutRecordingTarget = .command
                                        },
                                        onRemovePressed: {
                                            if self.activeShortcutRecordingTarget == .command {
                                                self.shortcutRecordingMessage = nil
                                                self.activeShortcutRecordingTarget = nil
                                            }
                                            self.commandModeShortcut = nil
                                            self.commandModeShortcutEnabled = false
                                        }
                                    )
                                    .settingsSearchTarget(.commandModeShortcut)
                                    Divider().opacity(0.2).padding(.vertical, 4)

                                    self.shortcutRow(
                                        content: .init(
                                            icon: "pencil.and.outline",
                                            iconColor: .secondary,
                                            title: "Edit Mode",
                                            description: "Select text and speak how to edit, or generate new content"
                                        ),
                                        shortcut: self.rewriteShortcut,
                                        isRecording: self.isRecording(.edit),
                                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                                        recordingMessage: self.isRecording(.edit) ? self.shortcutRecordingMessage : nil,
                                        isEnabled: self.$rewriteShortcutEnabled,
                                        onChangePressed: {
                                            DebugLogger.shared.debug("Starting to record new write mode shortcut", source: "SettingsView")
                                            self.shortcutRecordingMessage = nil
                                            self.activeShortcutRecordingTarget = .edit
                                        }
                                    )
                                    .settingsSearchTarget(.editModeShortcut)
                                    Divider().opacity(0.2).padding(.vertical, 4)

                                    self.shortcutRow(
                                        content: .init(
                                            icon: "xmark.circle.fill",
                                            iconColor: .secondary,
                                            title: "Cancel Recording",
                                            description: "Cancel the current recording or dismiss the active recording overlay"
                                        ),
                                        shortcut: self.cancelRecordingShortcut,
                                        isRecording: self.isRecording(.cancel),
                                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                                        recordingMessage: self.isRecording(.cancel) ? self.shortcutRecordingMessage : nil,
                                        onChangePressed: {
                                            DebugLogger.shared.debug("Starting to record new cancel shortcut", source: "SettingsView")
                                            self.shortcutRecordingMessage = nil
                                            self.activeShortcutRecordingTarget = .cancel
                                        }
                                    )
                                    .settingsSearchTarget(.cancelRecordingShortcut)
                                    Divider().opacity(0.2).padding(.vertical, 4)

                                    self.shortcutRow(
                                        content: .init(
                                            icon: "arrow.down.doc",
                                            iconColor: .secondary,
                                            title: "Paste Last Transcription",
                                            description: "Re-insert your most recent transcription without using the clipboard"
                                        ),
                                        shortcut: self.pasteLastTranscriptionShortcut,
                                        isRecording: self.isRecording(.pasteLast),
                                        isAnyRecordingActive: self.isRecordingAnyShortcut,
                                        recordingMessage: self.isRecording(.pasteLast) ? self.shortcutRecordingMessage : nil,
                                        isEnabled: self.$pasteLastTranscriptionShortcutEnabled,
                                        requiresShortcutToEnable: true,
                                        onChangePressed: {
                                            DebugLogger.shared.debug("Starting to record new paste last transcription shortcut", source: "SettingsView")
                                            self.shortcutRecordingMessage = nil
                                            self.activeShortcutRecordingTarget = .pasteLast
                                        },
                                        onRemovePressed: {
                                            if self.activeShortcutRecordingTarget == .pasteLast {
                                                self.shortcutRecordingMessage = nil
                                                self.activeShortcutRecordingTarget = nil
                                            }
                                            self.pasteLastTranscriptionShortcut = nil
                                            self.pasteLastTranscriptionShortcutEnabled = false
                                        }
                                    )
                                    .settingsSearchTarget(.pasteLastTranscriptionShortcut)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(self.theme.palette.elevatedCardBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(self.theme.palette.cardBorder.opacity(0.45), lineWidth: 1)
                                        )
                                )

                                // MARK: - Options Section

                                VStack(spacing: 12) {
                                    HStack(alignment: .center) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Activation Mode")
                                                .font(self.theme.typography.bodyStrong)
                                                .foregroundStyle(self.settingsTitleText)
                                            Text(self.hotkeyMode.description)
                                                .font(self.theme.typography.bodySmall)
                                                .foregroundStyle(self.settingsSecondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        Picker("", selection: self.$hotkeyMode) {
                                            ForEach(HotkeyActivationMode.allCases) { mode in
                                                Text(mode.displayName).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 170, alignment: .trailing)
                                    }
                                    .onChange(of: self.hotkeyMode) { _, newValue in
                                        SettingsStore.shared.hotkeyMode = newValue
                                        self.hotkeyManager?.setHotkeyMode(newValue)
                                    }
                                    .settingsSearchTarget(.activationMode)
                                    Divider().opacity(0.2)

                                    self.optionToggleRow(
                                        title: "Copy to Clipboard",
                                        description: "Automatically copy transcribed text to clipboard as a backup.",
                                        isOn: self.$copyToClipboard
                                    )
                                    .onChange(of: self.copyToClipboard) { _, newValue in
                                        SettingsStore.shared.copyTranscriptionToClipboard = newValue
                                    }
                                    .settingsSearchTarget(.copyToClipboard)
                                    Divider().opacity(0.2)

                                    HStack(alignment: .center) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Text Insertion Mode")
                                                .font(self.theme.typography.bodyStrong)
                                                .foregroundStyle(self.settingsTitleText)
                                            Text(SettingsStore.shared.textInsertionMode.description)
                                                .font(self.theme.typography.bodySmall)
                                                .foregroundStyle(self.settingsSecondaryText)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                        Picker("", selection: Binding(
                                            get: { SettingsStore.shared.textInsertionMode },
                                            set: { SettingsStore.shared.textInsertionMode = $0 }
                                        )) {
                                            ForEach(SettingsStore.TextInsertionMode.allCases) { mode in
                                                Text(mode.displayName).tag(mode)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .frame(width: 170, alignment: .trailing)
                                    }
                                    .settingsSearchTarget(.textInsertionMode)
                                    Divider().opacity(0.2)

                                    self.spokenSendSettings
                                        .settingsSearchTarget(.spokenSend)
                                    Divider().opacity(0.2)

                                    VocaSettingsDisclosure(title: "Saving, playback & learning") {
                                        VStack(spacing: 12) {
                                    self.optionToggleRow(
                                        title: "Save Transcription History",
                                        description: "Save transcriptions for stats tracking. Disable for privacy.",
                                        isOn: Binding(
                                            get: { SettingsStore.shared.saveTranscriptionHistory },
                                            set: {
                                                SettingsStore.shared.saveTranscriptionHistory = $0
                                                self.refreshAudioHistoryUsage()
                                            }
                                        )
                                    )
                                    .settingsSearchTarget(.transcriptionHistory)
                                    Divider().opacity(0.2)

                                    self.optionToggleRow(
                                        title: "Save Audio With History",
                                        description: "Store actual microphone audio locally with dictation history. Disabled by default.",
                                        isOn: Binding(
                                            get: { SettingsStore.shared.saveAudioWithTranscriptionHistory },
                                            set: {
                                                SettingsStore.shared.saveAudioWithTranscriptionHistory = $0
                                                self.refreshAudioHistoryUsage()
                                            }
                                        )
                                    )
                                    .disabled(!SettingsStore.shared.saveTranscriptionHistory)
                                    .settingsSearchTarget(.audioHistory)

                                    if SettingsStore.shared.saveTranscriptionHistory,
                                       SettingsStore.shared.saveAudioWithTranscriptionHistory
                                    {
                                        self.audioHistoryControls()
                                            .padding(.top, 2)
                                            .settingsSearchTarget(.audioStorage)
                                        Divider().opacity(0.2)
                                    } else {
                                        Divider().opacity(0.2)
                                    }

                                    self.optionToggleRow(
                                        title: "Weekends Don't Break Streak",
                                        description: "Skip Saturday and Sunday when calculating usage streaks. Perfect for weekday-only users.",
                                        isOn: Binding(
                                            get: { SettingsStore.shared.weekendsDontBreakStreak },
                                            set: { SettingsStore.shared.weekendsDontBreakStreak = $0 }
                                        )
                                    )
                                    .settingsSearchTarget(.usageStreak)
                                    Divider().opacity(0.2)

                                    self.optionToggleRow(
                                        title: "Skip Silent Recordings",
                                        description: "Avoid transcription when a recording up to four seconds contains only clear silence. Disabled by default to preserve quiet speech.",
                                        isOn: Binding(
                                            get: { SettingsStore.shared.skipSilentRecordingsEnabled },
                                            set: { SettingsStore.shared.skipSilentRecordingsEnabled = $0 }
                                        )
                                    )
                                    .settingsSearchTarget(.skipSilentRecordings)
                                    Divider().opacity(0.2)

                                    self.optionToggleRow(
                                        title: "Pause Media During Transcription",
                                        description: "Automatically pause currently playing audio/video when transcription starts. Resumes only if VOCA paused it.",
                                        isOn: Binding(
                                            get: { SettingsStore.shared.pauseMediaDuringTranscription },
                                            set: { SettingsStore.shared.pauseMediaDuringTranscription = $0 }
                                        )
                                    )
                                    .settingsSearchTarget(.pauseMedia)
                                    Divider().opacity(0.2)

                                    DictionarySuggestionsSettingsRow()
                                        .settingsSearchTarget(.dictionarySuggestions)
                                    Divider().opacity(0.2)

                                    self.optionToggleRow(
                                        title: "Share Detailed Anonymous Analytics",
                                        description: "Analytics are not configured in this preview. Your usage history remains on this Mac.",
                                        isOn: self.detailedAnalyticsToggleBinding
                                    )
                                    .disabled(!AnalyticsConfig.fromBundle().isConfigured)
                                    .settingsSearchTarget(.analyticsPrivacy)

                                    HStack {
                                        Button("What we collect") {
                                            self.showAnalyticsPrivacy = true
                                        }
                                        .buttonStyle(.link)

                                        Spacer()
                                    }
                                    .padding(.top, 6)
                                        }
                                    }
                                }
                                .padding(12)
                            }
                        } else {
                            Text("Enable Accessibility in the setup check above to use shortcuts and automatic insertion.")
                                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                .settingsSearchTarget(.accessibilityPermission)
                        }
                    }
                    .padding(16)
                }
                .shownInSettingsSection(.dictation, selectedSection: self.selectedSection)

                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Text Formatting", systemImage: "textformat")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        VStack(spacing: 16) {
                            self.settingsToggleRow(
                                title: "Lowercase First Letter",
                                description: "Start each transcription with a lowercase letter.",
                                isOn: Binding(
                                    get: { self.settings.gaavLowercaseFirstLetterEnabled },
                                    set: { self.settings.gaavLowercaseFirstLetterEnabled = $0 }
                                )
                            )
                            Divider().opacity(0.2)

                            self.settingsToggleRow(
                                title: "Remove Trailing Period",
                                description: "Drop a final period from transcriptions.",
                                isOn: Binding(
                                    get: { self.settings.gaavRemoveTrailingPeriodEnabled },
                                    set: { self.settings.gaavRemoveTrailingPeriodEnabled = $0 }
                                )
                            )
                            Divider().opacity(0.2)

                            self.settingsToggleRow(
                                title: "Slash Commands & @ Formatting",
                                description: "Convert spoken slash commands and supported @ mentions into symbols.",
                                isOn: Binding(
                                    get: { self.settings.literalDictationFormattingEnabled },
                                    set: { self.settings.literalDictationFormattingEnabled = $0 }
                                )
                            )
                            Divider().opacity(0.2)

                            self.settingsToggleRow(
                                title: "Space Between Dictations",
                                description: "Add spacing when consecutive dictations are joined.",
                                isOn: Binding(
                                    get: { self.settings.continuousDictationSpacingEnabled },
                                    set: { self.settings.continuousDictationSpacingEnabled = $0 }
                                )
                            )
                            Divider().opacity(0.2)

                            self.settingsToggleRow(
                                title: "Smart Capitalization",
                                description: "Use text before the cursor to choose uppercase or lowercase.",
                                isOn: Binding(
                                    get: { self.settings.contextAwareCapitalizationEnabled },
                                    set: { self.settings.contextAwareCapitalizationEnabled = $0 }
                                )
                            )
                        }
                    }
                    .padding(16)
                }
                .settingsSearchTarget(.textFormatting)
                .shownInSettingsSection(.dictation, selectedSection: self.selectedSection)

                // Notification Settings Card
                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            self.optionToggleRow(
                                title: "AI Enhancement Failures",
                                description: "Notify when AI Enhancement fails and raw transcription is typed.",
                                isOn: Binding(
                                    get: { SettingsStore.shared.notifyAIProcessingFailures },
                                    set: { SettingsStore.shared.notifyAIProcessingFailures = $0 }
                                )
                            )
                            .settingsSearchTarget(.aiEnhancementFailures)

                            Divider().opacity(0.2)

                            self.optionToggleRow(
                                title: "Microphone Changes",
                                description: "Show an alert when VOCA changes or loses its microphone.",
                                isOn: Binding(
                                    get: { self.settings.showMicrophoneChangeAlerts },
                                    set: { enabled in
                                        self.settings.showMicrophoneChangeAlerts = enabled
                                        if enabled == false {
                                            MicrophoneChangeOverlayController.shared.hide()
                                        }
                                    }
                                )
                            )
                            .settingsSearchTarget(.microphoneChanges)
                        }
                    }
                    .padding(16)
                }
                .shownInSettingsSection(.notifications, selectedSection: self.selectedSection)

                // Audio Devices Card
                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Label("Audio Devices", systemImage: "speaker.wave.2.fill")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Button {
                                self.refreshDevices()
                                // Update cached default device names on refresh
                                let defaultInput = AudioDevice.getDefaultInputDevice()
                                self.cachedDefaultInputUID = defaultInput?.uid ?? ""
                                self.cachedDefaultOutputName = AudioDevice.getDefaultOutputDevice()?.name ?? ""
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            self.microphonePrioritySection
                                .settingsSearchTarget(.inputDevicePriority)
                                .onChange(of: self.inputDevices) { _, newDevices in
                                    let defaultInput = AudioDevice.getDefaultInputDevice()
                                    self.cachedDefaultInputUID = defaultInput?.uid ?? ""
                                    guard newDevices.isEmpty == false else { return }
                                    if let selectedInput = self.appServices.microphonePreferenceCoordinator
                                        .reconcileMicrophoneSelection(
                                            availableInputs: newDevices,
                                            defaultInputUID: self.cachedDefaultInputUID
                                        )
                                    {
                                        self.selectedInputUID = selectedInput.uid
                                    }
                                }

                            HStack {
                                Text("Output Device")
                                    .font(self.theme.typography.bodyStrong)
                                    .foregroundStyle(self.settingsTitleText)
                                Spacer()
                                Picker("", selection: self.$selectedOutputUID) {
                                    // Handle empty state gracefully
                                    if self.outputDevices.isEmpty {
                                        Text("Loading...").tag("")
                                    } else {
                                        ForEach(self.outputDevices, id: \.uid) { dev in
                                            // Add "(System Default)" tag using cached name to avoid CoreAudio calls during layout
                                            let isSystemDefault = !self.cachedDefaultOutputName.isEmpty && dev.name == self.cachedDefaultOutputName
                                            Text(isSystemDefault ? "\(dev.name) (System Default)" : dev.name).tag(dev.uid)
                                        }
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 240)
                                .disabled(self.asr.isRunning) // Disable device changes during recording
                                .onChange(of: self.selectedOutputUID) { oldUID, newUID in
                                    guard !newUID.isEmpty else { return }

                                    // Prevent device changes during active recording
                                    if self.asr.isRunning {
                                        DebugLogger.shared.warning("Cannot change output device during recording", source: "SettingsView")
                                        // Revert to previous value
                                        self.selectedOutputUID = oldUID
                                        return
                                    }

                                    SettingsStore.shared.preferredOutputDeviceUID = newUID
                                    _ = AudioDevice.setDefaultOutputDevice(uid: newUID)
                                }
                                // Sync selection when devices load or change
                                .onChange(of: self.outputDevices) { _, newDevices in
                                    // Update cached default device name when device list changes
                                    self.cachedDefaultOutputName = AudioDevice.getDefaultOutputDevice()?.name ?? ""

                                    if !newDevices.isEmpty {
                                        let currentValid = newDevices.contains { $0.uid == self.selectedOutputUID }
                                        if !currentValid {
                                            if let prefUID = SettingsStore.shared.preferredOutputDeviceUID,
                                               newDevices.contains(where: { $0.uid == prefUID })
                                            {
                                                self.selectedOutputUID = prefUID
                                            } else if let defaultUID = AudioDevice.getDefaultOutputDevice()?.uid,
                                                      newDevices.contains(where: { $0.uid == defaultUID })
                                            {
                                                self.selectedOutputUID = defaultUID
                                            } else {
                                                self.selectedOutputUID = newDevices.first?.uid ?? ""
                                            }
                                        }
                                    }
                                }
                            }
                            .settingsSearchTarget(.outputDevice)

                            self.microphoneQualityGuidance
                        }
                    }
                    .padding(16)
                }
                .shownInSettingsSection(.audio, selectedSection: self.selectedSection)

                // A visual sample never starts capture or changes the active destination.
                VocaOverlayAppearancePreview(showTranscript: self.enableStreamingPreview && self.settings.overlayPosition != .caret, atNotch: self.settings.overlayPosition == .top)
                    .shownInSettingsSection(.overlay, selectedSection: self.selectedSection)

                // Overlay Settings Card
                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sensitivity")
                                        .font(self.theme.typography.bodyStrong)
                                        .foregroundStyle(self.settingsTitleText)
                                    Text("Control how sensitive the audio visualizer is to sound input")
                                        .font(self.theme.typography.bodySmall)
                                        .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Button("Reset") {
                                    self.visualizerNoiseThreshold = 0.4
                                    SettingsStore.shared.visualizerNoiseThreshold = self.visualizerNoiseThreshold
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .settingsSearchTarget(.overlaySensitivity)

                            HStack(spacing: 10) {
                                Text("More")
                                    .font(.caption)
                                    .foregroundStyle(self.settingsSecondaryText)
                                    .frame(width: 36, alignment: .trailing)

                                Slider(value: self.$visualizerNoiseThreshold, in: 0.01...0.8, step: 0.01)
                                    .controlSize(.regular)

                                Text("Less")
                                    .font(.caption)
                                    .foregroundStyle(self.settingsSecondaryText)
                                    .frame(width: 36, alignment: .leading)

                                Text(String(format: "%.2f", self.visualizerNoiseThreshold))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(self.settingsTertiaryText)
                                    .frame(width: 36)
                            }

                            Divider().padding(.vertical, 8)

                            // Overlay Position
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Overlay Position")
                                        .font(self.theme.typography.bodyStrong)
                                        .foregroundStyle(self.settingsTitleText)
                                    Text("Where the recording indicator appears on screen")
                                        .font(self.theme.typography.bodySmall)
                                        .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                Picker("", selection: self.$settings.overlayPosition) {
                                    ForEach(SettingsStore.OverlayPosition.allCases, id: \.self) { position in
                                        Text(position.displayName).tag(position)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 170, alignment: .trailing)
                            }
                            .settingsSearchTarget(.overlayPosition)

                            Divider().padding(.vertical, 8)

                            if self.settings.overlayPosition != .caret {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Transcription Preview Length")
                                                .font(self.theme.typography.bodyStrong)
                                                .foregroundStyle(self.settingsTitleText)
                                            Text("How many recent characters appear in the notch/pill preview")
                                                .font(self.theme.typography.bodySmall)
                                                .foregroundStyle(self.settingsSecondaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                        }

                                        Spacer()

                                        Text("\(self.settings.transcriptionPreviewCharLimit) chars")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(self.settingsSecondaryText)
                                    }

                                    HStack(spacing: 10) {
                                        Text("Less")
                                            .font(.caption)
                                            .foregroundStyle(self.settingsSecondaryText)
                                            .frame(width: 36, alignment: .trailing)

                                        Slider(
                                            value: Binding(
                                                get: { Double(self.settings.transcriptionPreviewCharLimit) },
                                                set: { self.settings.transcriptionPreviewCharLimit = Int($0.rounded()) }
                                            ),
                                            in: Double(SettingsStore.transcriptionPreviewCharLimitRange.lowerBound)...Double(SettingsStore.transcriptionPreviewCharLimitRange.upperBound),
                                            step: Double(SettingsStore.transcriptionPreviewCharLimitStep)
                                        )
                                        .controlSize(.regular)

                                        Text("More")
                                            .font(.caption)
                                            .foregroundStyle(self.settingsSecondaryText)
                                            .frame(width: 36, alignment: .leading)
                                    }
                                }
                                .settingsSearchTarget(.transcriptionPreviewLength)

                                Divider().padding(.vertical, 4)
                            }

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(self.settings.overlayPosition == .caret ? "Cursor Pill" : self.settings.overlayPosition == .bottom ? "Overlay Size" : "Notch Style")
                                        .font(self.theme.typography.bodyStrong)
                                        .foregroundStyle(self.settingsTitleText)
                                    Text(
                                        self.settings.overlayPosition == .caret
                                            ? "Places a compact pill around the typing cursor. Uses the screen edge when the app does not expose its cursor."
                                            : self.settings.overlayPosition == .bottom
                                            ? "How large the recording indicator appears"
                                            : "Open around the camera with an app icon and live waveform. Expanded controls are also available."
                                    )
                                    .font(self.theme.typography.bodySmall)
                                    .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                if self.settings.overlayPosition == .caret {
                                    Text("Compact").font(.callout).foregroundStyle(.secondary)
                                } else if self.settings.overlayPosition == .bottom {
                                    Picker("", selection: self.$settings.overlaySize) {
                                        ForEach(SettingsStore.OverlaySize.allCases, id: \.self) { size in
                                            Text(size.displayName).tag(size)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 170, alignment: .trailing)
                                } else {
                                    Picker("", selection: self.$settings.notchPresentationMode) {
                                        ForEach(SettingsStore.NotchPresentationMode.allCases, id: \.self) { mode in
                                            Text(mode.displayName).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 170, alignment: .trailing)
                                }
                            }
                            .settingsSearchTarget(.overlayStyle)

                            if self.settings.overlayPosition != .caret {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Live Preview")
                                            .font(self.theme.typography.bodyStrong)
                                            .foregroundStyle(self.settingsTitleText)
                                        Text("Show transcription text in the overlay while you speak")
                                            .font(self.theme.typography.bodySmall)
                                            .foregroundStyle(self.settingsSecondaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    Toggle("", isOn: self.$enableStreamingPreview)
                                        .labelsHidden()
                                        .onChange(of: self.enableStreamingPreview) { _, newValue in
                                            SettingsStore.shared.enableStreamingPreview = newValue
                                        }
                                }
                                .settingsSearchTarget(.livePreview)
                            }

                            // Bottom overlay specific settings (only show when bottom is selected)
                            if self.settings.overlayPosition == .bottom {
                                Divider().padding(.vertical, 4)

                                // Bottom Offset
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Bottom Offset")
                                            .font(self.theme.typography.bodyStrong)
                                            .foregroundStyle(self.settingsTitleText)
                                        Text("Distance from bottom of screen")
                                            .font(self.theme.typography.bodySmall)
                                            .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Slider(value: self.$settings.overlayBottomOffset, in: 20...500)
                                            .frame(width: 110)
                                            .controlSize(.small)

                                        Text("\(Int(self.settings.overlayBottomOffset)) px")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(self.settingsSecondaryText)
                                            .frame(width: 54, alignment: .trailing)
                                    }
                                    .frame(width: 170, alignment: .trailing)
                                }
                                .settingsSearchTarget(.bottomOffset)
                            }

                            if self.asr.isRunning {
                                Text("Settings are disabled during active recording")
                                    .font(.caption)
                                    .foregroundStyle(self.settingsSecondaryText)
                                    .italic()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 4)
                            }
                        }
                    }
                    .padding(16)
                }
                .shownInSettingsSection(.overlay, selectedSection: self.selectedSection)

                // Backup & Restore Card
                VocaSettingsGroup {
                    self.backupUtilityRow()
                        .padding(16)
                }
                .settingsSearchTarget(.backupAndRestore)
                .shownInSettingsSection(.dataAndDiagnostics, selectedSection: self.selectedSection)

                // Debug Settings Card
                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Debug Settings", systemImage: "ladybug.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            self.settingsToggleRow(
                                title: "Collect detailed diagnostics",
                                description: "Off by default. Diagnostic logs may contain dictated text and app context. Enable briefly for troubleshooting.",
                                isOn: Binding(
                                    get: { SettingsStore.shared.enableDebugLogs },
                                    set: { SettingsStore.shared.enableDebugLogs = $0 }
                                )
                            )

                            Divider().padding(.vertical, 8)

                            Button {
                                let url = FileLogger.shared.currentLogFileURL()
                                if FileManager.default.fileExists(atPath: url.path) {
                                    NSWorkspace.shared.activateFileViewerSelecting([url])
                                } else {
                                    DebugLogger.shared.info("Log file not found at \(url.path)", source: "SettingsView")
                                }
                            } label: {
                                Label("Reveal Log File", systemImage: "doc.richtext")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)

                            Text("Review logs before sharing. Disabling this stops new detailed logs; it does not delete existing files.")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                            Text("Use Reveal Log File to locate diagnostics stored on this Mac.")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                }
                .settingsSearchTarget(.debugLogs)
                .shownInSettingsSection(.dataAndDiagnostics, selectedSection: self.selectedSection)

                VocaSettingsGroup {
                    VStack(alignment: .leading, spacing: 14) {
                        self.settingsToggleRow(
                            title: "Faster Long Dictation",
                            description: "For long recordings, reuse completed live windows and process only the remaining tail when you stop.",
                            footnote: "Parakeet only. Falls back to normal transcription if reuse is unavailable or fails.",
                            isOn: Binding(
                                get: { SettingsStore.shared.experimentalParakeetUnifiedFinalEnabled },
                                set: { SettingsStore.shared.experimentalParakeetUnifiedFinalEnabled = $0 }
                            )
                        )

                        Divider().padding(.vertical, 4)

                        self.settingsToggleRow(
                            title: "Show Performance in History",
                            description: "Display transcription and text enhancement timings.",
                            isOn: Binding(
                                get: { SettingsStore.shared.showHistoryPerformanceMetrics },
                                set: { SettingsStore.shared.showHistoryPerformanceMetrics = $0 }
                            )
                        )
                        .settingsSearchTarget(.historyPerformance)
                    }
                    .padding(16)
                }
                .settingsSearchTarget(.fasterLongDictation)
                .shownInSettingsSection(.experimental, selectedSection: self.selectedSection)
            }
            .frame(maxWidth: 840).padding(28).frame(maxWidth: .infinity)
            .environment(\.settingsSearchPresentation, self.settingsSearchPresentation)
        }
        .id(self.selectedSection)
        .transition(.opacity)
        .sheet(isPresented: self.$showAnalyticsPrivacy) {
            AnalyticsPrivacyView()
                .frame(minWidth: 520, minHeight: 520)
                .appTheme(self.theme)
        }
        .sheet(isPresented: self.detailedAnalyticsConfirmationBinding) {
            AnalyticsConfirmationView(
                onConfirm: {
                    if let pending = pendingDetailedAnalyticsValue {
                        self.shareDetailedAnalytics = pending
                        self.applyAnalyticsConsentChange(pending)
                    }
                    self.pendingDetailedAnalyticsValue = nil
                    self.showDetailedAnalyticsConfirmation = false
                },
                onCancel: {
                    self.pendingDetailedAnalyticsValue = nil
                    self.showDetailedAnalyticsConfirmation = false
                }
            )
        }
        .task(id: self.selectedSection) {
            await self.prepareSelectedSection()
        }
        .onChange(of: self.visualizerNoiseThreshold) { _, newValue in
            SettingsStore.shared.visualizerNoiseThreshold = newValue
        }
    }

    private func refreshRollbackState() {
        self.rollbackVersion = SimpleUpdater.shared.latestRollbackVersion() ?? ""
    }

    private func openIssueReportingPage() {
        VocaProduct.navigate("feedback")
    }

    private func exportBackup() {
        Task { await self.performBackupExport() }
    }

    private func performBackupExport() async {
        do {
            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = BackupService.shared.suggestedFilename()

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let document = try await BackupService.shared.makeBackupDocument()
            let data = try BackupService.shared.encode(document)
            try data.write(to: url, options: .atomic)

            self.presentInfoAlert(
                title: "Backup Exported",
                message: "Saved your VOCA backup to:\n\(url.path)"
            )
        } catch {
            self.presentErrorAlert(
                title: "Backup Export Failed",
                message: error.localizedDescription
            )
        }
    }

    private func importBackup() {
        Task { await self.performBackupImport() }
    }

    private func performBackupImport() async {
        do {
            let panel = NSOpenPanel()
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowsMultipleSelection = false
            panel.allowedContentTypes = [.json]

            guard panel.runModal() == .OK, let url = panel.url else { return }

            let data = try Data(contentsOf: url)
            let document = try BackupService.shared.decode(data)

            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short

            let confirm = NSAlert()
            confirm.messageText = "Import this backup?"
            confirm.informativeText = """
            This replaces your current settings, prompt profiles, and stats history.

            Exported: \(formatter.string(from: document.exportedAt))
            API keys are not included and will not be changed.
            """
            confirm.alertStyle = .warning
            confirm.addButton(withTitle: "Import")
            confirm.addButton(withTitle: "Cancel")

            guard confirm.runModal() == .alertFirstButtonReturn else { return }

            try await BackupService.shared.restore(document)
            self.syncLocalSettingsAfterBackupRestore()

            self.presentInfoAlert(
                title: "Backup Imported",
                message: "Your settings, prompt profiles, and stats were restored successfully."
            )
        } catch {
            self.presentErrorAlert(
                title: "Backup Import Failed",
                message: error.localizedDescription
            )
        }
    }

    private func syncLocalSettingsAfterBackupRestore() {
        self.shareDetailedAnalytics = SettingsStore.shared.shareDetailedAnalytics
        self.pendingDetailedAnalyticsValue = nil
        self.showDetailedAnalyticsConfirmation = false
        self.refreshAudioHistoryUsage()
    }

    private func refreshAudioHistoryUsage() {
        self.audioHistoryUsageBytes = DictationAudioHistoryStore.shared.audioUsageBytes()
        self.audioHistoryBudgetText = Self.audioBudgetText(for: SettingsStore.shared.audioHistoryBudgetGB)
    }

    private func applyAudioHistoryBudget() {
        let normalized = self.audioHistoryBudgetText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else {
            self.presentErrorAlert(title: "Invalid Budget", message: "Enter a positive number of GB.")
            self.refreshAudioHistoryUsage()
            return
        }

        let newBudget = max(0.1, value)
        let newBudgetBytes = DictationAudioHistoryStore.bytes(forGigabytes: newBudget)
        if self.audioHistoryUsageBytes > newBudgetBytes {
            let confirm = NSAlert()
            confirm.messageText = "Prune saved audio?"
            confirm.informativeText = """
            This budget is below current audio usage. VOCA will delete the oldest saved audio first and keep transcript history.
            """
            confirm.alertStyle = .warning
            confirm.addButton(withTitle: "Apply and Prune")
            confirm.addButton(withTitle: "Cancel")
            guard confirm.runModal() == .alertFirstButtonReturn else {
                self.refreshAudioHistoryUsage()
                return
            }
        }

        SettingsStore.shared.audioHistoryBudgetGB = newBudget
        let pruned = TranscriptionHistoryStore.shared.pruneAudioToBudget()
        self.refreshAudioHistoryUsage()
        if pruned > 0 {
            self.presentInfoAlert(title: "Audio Pruned", message: "Deleted oldest saved audio from \(pruned) history entries.")
        }
    }

    private func deleteSavedAudio() {
        let confirm = NSAlert()
        confirm.messageText = "Delete saved audio?"
        confirm.informativeText = "This removes saved dictation audio only. Transcript history stays intact."
        confirm.alertStyle = .warning
        confirm.addButton(withTitle: "Delete Audio")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        let removed = TranscriptionHistoryStore.shared.deleteAllSavedAudio()
        self.refreshAudioHistoryUsage()
        self.presentInfoAlert(title: "Audio Deleted", message: "Removed audio from \(removed) history entries.")
    }

    private func exportAudioZip() {
        do {
            guard TranscriptionHistoryStore.shared.entries.contains(where: {
                DictationAudioHistoryStore.shared.audioFileExists(for: $0)
            }) else {
                throw DictationAudioHistoryError.noAudioEntries
            }

            let panel = NSSavePanel()
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.zip]
            panel.nameFieldStringValue = DictationAudioHistoryStore.shared.suggestedAudioExportFilename()

            guard panel.runModal() == .OK, let url = panel.url else { return }
            try DictationAudioHistoryStore.shared.exportAudioArchive(
                entries: TranscriptionHistoryStore.shared.entries,
                to: url
            )
            self.presentInfoAlert(title: "Audio Export Saved", message: "Saved your dictation audio export to:\n\(url.path)")
        } catch {
            self.presentErrorAlert(title: "Audio Export Failed", message: error.localizedDescription)
        }
    }

    private func presentInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func openPreviousBuildPicker() {
        VocaProduct.showUpdateStatus()
    }

    private func presentPreviousBuildPicker(_ options: [SimpleUpdater.ReleaseBuildOption]) {
        guard !options.isEmpty else {
            self.openAllReleasesPage()
            return
        }

        let picker = NSAlert()
        picker.messageText = "Download Previous Build"
        picker.informativeText = "No local rollback backup was found. Choose a recent release build:"
        picker.alertStyle = .informational

        for option in options {
            picker.addButton(withTitle: option.version)
        }
        picker.addButton(withTitle: "All Releases")
        picker.addButton(withTitle: "Cancel")

        let response = picker.runModal()
        let first = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        let index = response.rawValue - first

        if index >= 0, index < options.count {
            NSWorkspace.shared.open(options[index].url)
            return
        }
        if index == options.count {
            self.openAllReleasesPage()
        }
    }

    private func openAllReleasesPage() {
        VocaProduct.navigate("notes")
    }

    private func applyAnalyticsConsentChange(_ enabled: Bool) {
        SettingsStore.shared.shareDetailedAnalytics = enabled
        AnalyticsService.shared.setDetailedAnalyticsEnabled(enabled)
    }

    // MARK: - Helper Views

    private func settingsToggleRow(title: String, description: String, footnote: String? = nil,
                                   errorMessage: String? = nil, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VocaPreferenceRow(title: title, detail: description, isOn: isOn)
            if let footnote { Text(footnote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(self.theme.palette.warning).fixedSize(horizontal: false, vertical: true) }
        }
    }

    private var sectionSubtitle: String {
        switch self.selectedSection {
        case .general: return "Appearance, startup, and sound."
        case .dictation: return "Your shortcut. Your words. Right where you need them."
        case .audio: return "Choose what VOCA hears, and where sound plays."
        case .overlay: return "A quiet sign that VOCA is listening."
        case .notifications: return "Stay informed, with fewer interruptions."
        case .dataAndDiagnostics: return "Your recordings, storage, and troubleshooting tools."
        case .experimental: return "Try new capabilities at your own pace."
        }
    }

    private var insertionSetupSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(self.accessibilityEnabled && self.asr.micStatus == .authorized ? "Ready to check your destination" : "Let’s get you ready to dictate", systemImage: "cursorarrow.rays")
                .font(.headline)
            Text("Confirm microphone access and test automatic insertion in the app you use.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { self.setupActions }
                VStack(alignment: .leading, spacing: 12) { self.setupActions }
            }
        }.padding(22).vocaContentSurface().settingsSearchTarget(.microphonePermission)
    }

    @ViewBuilder private var setupActions: some View {
        Button("Check permissions & insertion", systemImage: "checkmark.circle") { VocaProduct.navigate("destination") }.fluidButton(.primary, size: .small)
        Button("Quick Controls", systemImage: "slider.horizontal.3") { VocaProduct.navigate("quickControls") }.buttonStyle(.borderless)
    }

    private func backupUtilityRow() -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.headline)
                .foregroundStyle(.primary)
                .frame(width: 24, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text("Backup & Restore")
                    .font(self.theme.typography.bodyStrong)
                    .foregroundStyle(self.settingsTitleText)
                Text("Export or import settings, prompt profiles, history, and stats. API keys excluded.")
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                Button(action: self.exportBackup) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(self.theme.palette.accent)
                .controlSize(.regular)

                Button(action: self.importBackup) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
    }

    private func audioHistoryControls() -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Audio Storage")
                        .font(self.theme.typography.bodyStrong)
                        .foregroundStyle(self.settingsTitleText)
                    Text("Audio history: \(DictationAudioHistoryStore.formattedGigabytes(self.audioHistoryUsageBytes)) / \(Self.audioBudgetText(for: SettingsStore.shared.audioHistoryBudgetGB)) GB Budget")
                        .font(self.theme.typography.bodySmall)
                        .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)

                    ProgressView(value: self.audioHistoryUsageFraction())
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 220)
                }

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    Text("Budget")
                        .font(.caption)
                        .foregroundStyle(self.settingsSecondaryText)

                    TextField("4", text: self.$audioHistoryBudgetText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)

                    Text("GB")
                        .font(.caption)
                        .foregroundStyle(self.settingsSecondaryText)

                    Button("Apply") {
                        self.applyAudioHistoryBudget()
                    }
                    .controlSize(.small)
                }
            }

            Divider().opacity(0.2)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Export Audio")
                        .font(self.theme.typography.bodyStrong)
                        .foregroundStyle(self.settingsTitleText)
                    Text("ZIP with manifest.jsonl and WAV audio.")
                        .font(self.theme.typography.bodySmall)
                        .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 16)

                Button {
                    self.exportAudioZip()
                } label: {
                    Label("Export ZIP", systemImage: "square.and.arrow.up")
                }
                .controlSize(.small)

                Button(role: .destructive) {
                    self.deleteSavedAudio()
                } label: {
                    Label("Delete Audio", systemImage: "trash")
                }
                .controlSize(.small)
                .disabled(self.audioHistoryUsageBytes <= 0)
            }
        }
    }

    private static func audioBudgetText(for value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private func audioHistoryUsageFraction() -> Double {
        let budget = SettingsStore.shared.audioHistoryBudgetBytes
        guard budget > 0 else { return 0 }
        return min(1, Double(self.audioHistoryUsageBytes) / Double(budget))
    }

    private func optionToggleRow(title: String, description: String, isOn: Binding<Bool>) -> some View {
        VocaPreferenceRow(title: title, detail: description, isOn: isOn)
    }

    private func instructionsBox(
        title: String,
        steps: [String],
        warningStyle: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(warningStyle ? self.theme.palette.warning : self.theme.palette.accent)
                    .font(.caption)
                Text(title)
                    .font(self.theme.typography.bodySmallStrong)
                    .foregroundStyle(self.settingsTitleText)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundStyle(warningStyle ? self.theme.palette.warning : self.theme.palette.accent)
                            .fontWeight(.semibold)
                            .frame(width: 16, alignment: .trailing)
                        Text(.init(step))
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((warningStyle ? self.theme.palette.warning : self.theme.palette.accent).opacity(0.12))
        )
    }

    @ViewBuilder
    private func primaryDictationShortcutsList() -> some View {
        let addTarget = ShortcutRecordingTarget.primaryDictation(.add)
        let isAdding = self.isRecording(addTarget)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "mic.fill")
                    .foregroundStyle(self.settingsSecondaryText)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Primary Dictation Shortcuts")
                        .font(self.theme.typography.bodyStrong)
                        .foregroundStyle(self.settingsTitleText)
                    Text("Use any keyboard shortcut, auxiliary mouse button, or modified click.")
                        .font(self.theme.typography.bodySmall)
                        .foregroundStyle(self.settingsSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    if isAdding {
                        self.shortcutRecordingMessage = nil
                        self.activeShortcutRecordingTarget = nil
                    } else {
                        DebugLogger.shared.debug("Starting to record new primary dictation shortcut", source: "SettingsView")
                        self.shortcutRecordingMessage = nil
                        self.activeShortcutRecordingTarget = addTarget
                    }
                } label: {
                    Label(isAdding ? "Cancel" : "Add shortcut", systemImage: isAdding ? "xmark" : "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isAdding && self.isRecordingAnyShortcut)
            }

            ForEach(Array(self.primaryDictationShortcuts.enumerated()), id: \.offset) { index, shortcut in
                self.primaryDictationShortcutRow(shortcut: shortcut, index: index)
            }

            if isAdding {
                self.primaryDictationShortcutCaptureStatus(for: addTarget)
            }
        }
    }

    @ViewBuilder
    private func primaryDictationShortcutRow(shortcut: HotkeyShortcut, index: Int) -> some View {
        let target = ShortcutRecordingTarget.primaryDictation(.replace(index))
        let isRecording = self.isRecording(target)

        HStack(spacing: 10) {
            Color.clear
                .frame(width: 20)

            if isRecording {
                self.shortcutCapturePill()
            } else {
                self.shortcutDisplayPill(shortcut.displayString)
            }

            Button(isRecording ? "Cancel" : "Change") {
                if isRecording {
                    self.shortcutRecordingMessage = nil
                    self.activeShortcutRecordingTarget = nil
                } else {
                    DebugLogger.shared.debug("Starting to record replacement primary dictation shortcut", source: "SettingsView")
                    self.shortcutRecordingMessage = nil
                    self.activeShortcutRecordingTarget = target
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!isRecording && self.isRecordingAnyShortcut)

            Button("Remove") {
                guard self.primaryDictationShortcuts.count > 1,
                      self.primaryDictationShortcuts.indices.contains(index)
                else { return }
                self.primaryDictationShortcuts.remove(at: index)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(self.primaryDictationShortcuts.count <= 1 || self.isRecordingAnyShortcut)

            if isRecording,
               let recordingMessage = self.shortcutRecordingMessage,
               !recordingMessage.isEmpty
            {
                Text(recordingMessage)
                    .font(.caption)
                    .foregroundStyle(self.theme.palette.warning)
            }
        }
    }

    private func primaryDictationShortcutCaptureStatus(for target: ShortcutRecordingTarget) -> some View {
        HStack(spacing: 10) {
            Color.clear
                .frame(width: 20)

            self.shortcutCapturePill()

            if self.isRecording(target),
               let recordingMessage = self.shortcutRecordingMessage,
               !recordingMessage.isEmpty
            {
                Text(recordingMessage)
                    .font(.caption)
                    .foregroundStyle(self.theme.palette.warning)
            }
        }
    }

    private func shortcutCapturePill() -> some View {
        Text("Press shortcut...")
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.orange.opacity(0.2))
            )
    }

    private func shortcutDisplayPill(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced().weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(.primary.opacity(0.15), lineWidth: 1)
                    )
            )
    }

    @ViewBuilder
    private func shortcutRow(
        content: ShortcutRowContent,
        shortcut: HotkeyShortcut?,
        isRecording: Bool,
        isAnyRecordingActive: Bool,
        recordingMessage: String? = nil,
        isEnabled: Binding<Bool>? = nil,
        requiresShortcutToEnable: Bool = false,
        onChangePressed: @escaping () -> Void,
        onRemovePressed: (() -> Void)? = nil
    ) -> some View {
        let enabledValue = isEnabled?.wrappedValue ?? true
        let hasShortcut = shortcut != nil
        let enableToggleDisabled = isAnyRecordingActive || (requiresShortcutToEnable && !hasShortcut)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: content.icon)
                    .foregroundStyle(content.iconColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(content.title)
                        .font(self.theme.typography.bodyStrong)
                        .foregroundStyle(self.settingsTitleText)
                    Text(content.description)
                        .font(self.theme.typography.bodySmall)
                        .foregroundStyle(self.settingsSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if let isEnabled {
                    Toggle("", isOn: isEnabled)
                        .toggleStyle(.switch)
                        .tint(self.theme.palette.accent)
                        .labelsHidden()
                        .disabled(enableToggleDisabled)
                }
            }

            HStack(spacing: 10) {
                Color.clear
                    .frame(width: 20)

                if isRecording {
                    self.shortcutCapturePill()
                } else {
                    self.shortcutDisplayPill(shortcut?.displayString ?? "Not set")
                }

                Button(isRecording ? "Cancel" : "Change") {
                    if isRecording {
                        self.shortcutRecordingMessage = nil
                        self.activeShortcutRecordingTarget = nil
                    } else {
                        onChangePressed()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!isRecording && (isAnyRecordingActive || (!enabledValue && hasShortcut)))

                if let onRemovePressed {
                    Button("Remove") {
                        onRemovePressed()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!hasShortcut || isAnyRecordingActive)
                }

                if isRecording, let recordingMessage, !recordingMessage.isEmpty {
                    Text(recordingMessage)
                        .font(.caption)
                        .foregroundStyle(self.theme.palette.warning)
                }
            }
        }
        .opacity(enabledValue ? 1 : 0.7)
    }
}

private extension SettingsView {
    var isRecordingAnyShortcut: Bool {
        self.activeShortcutRecordingTarget != nil
    }

    var selectedSectionSearchResults: [SettingsSearchResult] {
        self.searchResults.filter { $0.section == self.selectedSection }
    }

    var settingsSearchPresentation: SettingsSearchPresentation? {
        guard let primaryTarget = self.selectedSectionSearchResults.first?.target else { return nil }
        return SettingsSearchPresentation(
            matchedTargets: Set(self.selectedSectionSearchResults.map(\.target)),
            primaryTarget: primaryTarget,
            scrollCoordinator: self.searchScrollCoordinator
        )
    }

    var settingsTitleText: Color {
        Color(nsColor: .labelColor)
    }

    var settingsSecondaryText: Color {
        self.colorScheme == .light ? Color(nsColor: .labelColor).opacity(0.90) : self.theme.palette.primaryText.opacity(0.82)
    }

    var settingsTertiaryText: Color {
        self.colorScheme == .light ? Color(nsColor: .labelColor).opacity(0.85) : self.theme.palette.secondaryText
    }

    var microphonePrioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Input Device Priority")
                    .font(self.theme.typography.bodyStrong)
                    .foregroundStyle(self.settingsTitleText)

                Spacer()

                if self.settings.suppressedMicrophoneUIDs.isEmpty == false {
                    Button {
                        self.settings.restoreRemovedMicrophones(with: self.inputDevices)
                        self.refreshActiveInputSelection()
                    } label: {
                        Label("Restore Removed", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(.plain)
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(self.theme.palette.accent)
                    .disabled(self.isMicrophonePriorityEditingDisabled)
                }
            }

            VStack(spacing: 0) {
                if self.settings.microphonePriority.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.slash")
                            .foregroundStyle(self.settingsSecondaryText)
                        Text(self.inputDevices.isEmpty ? "No microphones available" : "No microphones in priority")
                            .font(self.theme.typography.bodySmall)
                            .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                } else {
                    ForEach(Array(self.settings.microphonePriority.enumerated()), id: \.element.uid) { index, entry in
                        if index > 0 {
                            Divider().opacity(0.55)
                        }
                        self.microphonePriorityRow(entry, rank: index + 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(self.theme.palette.cardBackground.opacity(self.colorScheme == .light ? 0.72 : 0.52))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(self.theme.palette.cardBorder.opacity(0.7), lineWidth: 1)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text("VOCA tries microphones from top to bottom. Drag to reorder; unavailable devices keep their place.")
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(self.settingsSecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    func microphonePriorityRow(
        _ entry: SettingsStore.MicrophonePriorityEntry,
        rank: Int
    ) -> some View {
        let connectedDevice = self.inputDevices.first { $0.uid == entry.uid }
        let isAvailable = connectedDevice.map {
            self.appServices.microphonePreferenceCoordinator.isInputDeviceAvailable($0)
        } ?? false
        let isActive = entry.uid == self.microphonePreferenceCoordinator.confirmedActiveInputUID && isAvailable
        let isHovered = self.hoveredMicrophoneUID == entry.uid

        return HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(self.settingsTertiaryText.opacity(self.isMicrophonePriorityEditingDisabled ? 0.35 : 0.72))
                .frame(width: 18, height: 30)
                .contentShape(Rectangle())
                .onDrag {
                    self.draggedMicrophoneUID = entry.uid
                    return NSItemProvider(object: entry.uid as NSString)
                } preview: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(self.theme.palette.cardBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(self.theme.palette.cardBorder.opacity(0.8), lineWidth: 1)
                            )

                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(self.settingsTitleText)
                    }
                    .frame(width: 30, height: 30)
                    .shadow(color: Color.black.opacity(0.18), radius: 5, y: 2)
                }
                .allowsHitTesting(self.isMicrophonePriorityEditingDisabled == false)
                .accessibilityHidden(true)

            Text("\(rank).")
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()
                .frame(width: 22, alignment: .trailing)

            Text(entry.name)
                .font(self.theme.typography.bodyStrong)
                .foregroundStyle(isAvailable ? self.settingsTitleText : self.settingsSecondaryText)
                .lineLimit(1)

            Spacer(minLength: 8)

            if isHovered {
                Button(role: .destructive) {
                    self.removeMicrophonePriorityEntry(entry)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .systemRed).opacity(0.82))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(self.isMicrophonePriorityEditingDisabled)
                .help("Remove \(entry.name) from microphone priority")
                .accessibilityLabel("Remove \(entry.name)")
                .transition(.opacity)
            } else if isActive {
                Circle()
                    .fill(Color(nsColor: .systemGreen))
                    .frame(width: 7, height: 7)
                    .shadow(color: Color(nsColor: .systemGreen).opacity(0.45), radius: 3)
                    .accessibilityLabel("Active microphone")
            } else if isAvailable == false {
                Text("Unavailable")
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
        .contentShape(Rectangle())
        .opacity(isAvailable ? 1 : 0.62)
        .onHover { isHovering in
            let animation: Animation? = self.accessibilityReduceMotion ? nil : .easeOut(duration: 0.12)
            withAnimation(animation) {
                if isHovering {
                    self.hoveredMicrophoneUID = entry.uid
                } else if self.hoveredMicrophoneUID == entry.uid {
                    self.hoveredMicrophoneUID = nil
                }
            }
        }
        .onDrop(
            of: [UTType.plainText.identifier],
            delegate: MicrophonePriorityDropDelegate(
                targetUID: entry.uid,
                settings: self.settings,
                draggedUID: self.$draggedMicrophoneUID,
                reorderAnimation: self.accessibilityReduceMotion ? nil : .easeInOut(duration: 0.16),
                onDropCompleted: self.refreshActiveInputSelection
            )
        )
        .contextMenu {
            Button("Move Up") {
                self.settings.moveMicrophonePriority(uid: entry.uid, by: -1)
                self.refreshActiveInputSelection()
            }
            .disabled(self.isMicrophonePriorityEditingDisabled || rank == 1)

            Button("Move Down") {
                self.settings.moveMicrophonePriority(uid: entry.uid, by: 1)
                self.refreshActiveInputSelection()
            }
            .disabled(self.isMicrophonePriorityEditingDisabled || rank == self.settings.microphonePriority.count)

            Divider()

            Button("Remove from Priority", role: .destructive) {
                self.removeMicrophonePriorityEntry(entry)
            }
            .disabled(self.isMicrophonePriorityEditingDisabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Priority \(rank), \(entry.name)")
        .accessibilityValue(isActive ? "Active" : (isAvailable ? "Available" : "Unavailable"))
        .accessibilityAction(named: "Move up") {
            guard self.isMicrophonePriorityEditingDisabled == false, rank > 1 else { return }
            self.settings.moveMicrophonePriority(uid: entry.uid, by: -1)
            self.refreshActiveInputSelection()
        }
        .accessibilityAction(named: "Move down") {
            guard self.isMicrophonePriorityEditingDisabled == false,
                  rank < self.settings.microphonePriority.count
            else { return }
            self.settings.moveMicrophonePriority(uid: entry.uid, by: 1)
            self.refreshActiveInputSelection()
        }
        .accessibilityAction(named: "Remove from priority") {
            guard self.isMicrophonePriorityEditingDisabled == false else { return }
            self.removeMicrophonePriorityEntry(entry)
        }
    }

    var isMicrophonePriorityEditingDisabled: Bool {
        self.asr.isRunning || self.asr.isStarting
    }

    func refreshActiveInputSelection() {
        // Reuse the existing off-main hardware refresh so the green active
        // indicator and next capture resolve from live Core Audio.
        self.refreshDevices()
    }

    func removeMicrophonePriorityEntry(_ entry: SettingsStore.MicrophonePriorityEntry) {
        self.hoveredMicrophoneUID = nil
        self.settings.removeMicrophoneFromPriority(
            uid: entry.uid,
            isConnected: self.inputDevices.contains { $0.uid == entry.uid }
        )
        self.refreshActiveInputSelection()
    }

    var selectedInputDevice: AudioDevice.Device? {
        guard let confirmedUID = self.microphonePreferenceCoordinator.confirmedActiveInputUID else {
            return nil
        }
        return self.inputDevices.first { $0.uid == confirmedUID }
    }

    @ViewBuilder
    var microphoneQualityGuidance: some View {
        if self.selectedInputDevice?.isBluetooth == true {
            self.microphoneQualityGuidanceRow(
                message: "Bluetooth microphone mode can reduce headphone playback quality. Prefer a wired, USB, or display microphone when available.",
                systemImage: "exclamationmark.triangle.fill",
                color: self.theme.palette.warning
            )
        } else {
            self.microphoneQualityGuidanceRow(
                message: "This order applies only to VOCA and does not change your macOS input.",
                systemImage: "info.circle",
                color: self.settingsSecondaryText
            )
        }
    }

    func microphoneQualityGuidanceRow(
        message: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(color)
            Text(message)
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension SettingsView {
    func prepareSelectedSection() async {
        do {
            try await Task.sleep(nanoseconds: self.accessibilityReduceMotion ? 120_000_000 : 240_000_000)
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        switch self.selectedSection {
        case .general:
            self.refreshRollbackState()
            self.settings.refreshLaunchAtStartupStatus(clearError: true, logMismatch: false)
        case .audio:
            await self.prepareAudioSettings()
        case .dictation:
            await self.refreshAudioHistoryUsageInBackground()
        case .notifications, .overlay, .dataAndDiagnostics, .experimental:
            break
        }
    }

    func prepareAudioSettings() async {
        // Keep Core Audio initialization out of the navigation transaction.
        await AudioStartupGate.shared.scheduleOpenAfterInitialUISettled()
        await AudioStartupGate.shared.waitUntilOpen()
        guard !Task.isCancelled else { return }

        self.refreshDevices()

        if !self.inputDevices.isEmpty {
            let defaultInput = AudioDevice.getDefaultInputDevice()
            self.cachedDefaultInputUID = defaultInput?.uid ?? ""
            if let selectedInput = self.appServices.microphonePreferenceCoordinator
                .reconcileMicrophoneSelection(
                    availableInputs: self.inputDevices,
                    defaultInputUID: self.cachedDefaultInputUID
                )
            {
                self.selectedInputUID = selectedInput.uid
            }
        }

        if !self.outputDevices.isEmpty {
            let outputValid = self.outputDevices.contains { $0.uid == self.selectedOutputUID }
            if !outputValid || self.selectedOutputUID.isEmpty {
                if let prefUID = SettingsStore.shared.preferredOutputDeviceUID,
                   self.outputDevices.contains(where: { $0.uid == prefUID })
                {
                    self.selectedOutputUID = prefUID
                } else if let defaultUID = AudioDevice.getDefaultOutputDevice()?.uid,
                          self.outputDevices.contains(where: { $0.uid == defaultUID })
                {
                    self.selectedOutputUID = defaultUID
                } else {
                    self.selectedOutputUID = self.outputDevices.first?.uid ?? ""
                }
            }
        }

        // Cache hardware names outside body evaluation to avoid the Core Audio/AttributeGraph race.
        let defaultInput = AudioDevice.getDefaultInputDevice()
        self.cachedDefaultInputUID = defaultInput?.uid ?? ""
        self.cachedDefaultOutputName = AudioDevice.getDefaultOutputDevice()?.name ?? ""
    }

    func refreshAudioHistoryUsageInBackground() async {
        let usageBytes = await Task.detached(priority: .utility) {
            DictationAudioHistoryStore.shared.audioUsageBytes()
        }.value
        guard !Task.isCancelled else { return }

        self.audioHistoryUsageBytes = usageBytes
        self.audioHistoryBudgetText = Self.audioBudgetText(for: SettingsStore.shared.audioHistoryBudgetGB)
    }
}

private struct MicrophonePriorityDropDelegate: DropDelegate {
    let targetUID: String
    let settings: SettingsStore
    @Binding var draggedUID: String?
    let reorderAnimation: Animation?
    let onDropCompleted: () -> Void

    func validateDrop(info _: DropInfo) -> Bool {
        self.draggedUID != nil
    }

    func dropEntered(info _: DropInfo) {
        guard let draggedUID = self.draggedUID,
              draggedUID != self.targetUID
        else { return }

        let entries = self.settings.microphonePriority
        guard let sourceIndex = entries.firstIndex(where: { $0.uid == draggedUID }),
              let targetIndex = entries.firstIndex(where: { $0.uid == self.targetUID })
        else { return }

        withAnimation(self.reorderAnimation) {
            self.settings.reorderMicrophonePriority(
                fromOffsets: IndexSet(integer: sourceIndex),
                toOffset: targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
            )
        }
    }

    func dropUpdated(info _: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info _: DropInfo) -> Bool {
        self.draggedUID = nil
        self.onDropCompleted()
        return true
    }
}

private extension View {
    @ViewBuilder
    func shownInSettingsSection(_ section: SettingsSection, selectedSection: SettingsSection) -> some View {
        if section == selectedSection {
            self
        }
    }
}

// MARK: - Filler Words Editor

struct FillerWordsEditor: View {
    @State private var fillerWords: [String] = SettingsStore.shared.fillerWords
    @State private var newWord: String = ""
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filler words to remove:")
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(.secondary)

            // Word chips
            FlowLayout(spacing: 6) {
                ForEach(self.fillerWords, id: \.self) { word in
                    HStack(spacing: 4) {
                        Text(word)
                            .font(.caption)
                        Button {
                            self.removeWord(word)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.quaternary)
                    )
                }
            }

            // Add new word
            HStack(spacing: 8) {
                TextField("Add word", text: self.$newWord)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onSubmit { self.addWord() }

                Button("Add") { self.addWord() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(self.newWord.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()

                Button("Reset") {
                    self.fillerWords = SettingsStore.defaultFillerWords
                    SettingsStore.shared.fillerWords = self.fillerWords
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func addWord() {
        let word = self.newWord.trimmingCharacters(in: .whitespaces).lowercased()
        guard !word.isEmpty, !self.fillerWords.contains(word) else { return }
        self.fillerWords.append(word)
        SettingsStore.shared.fillerWords = self.fillerWords
        self.newWord = ""
    }

    private func removeWord(_ word: String) {
        self.fillerWords.removeAll { $0 == word }
        SettingsStore.shared.fillerWords = self.fillerWords
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    struct Cache {
        var sizes: [CGSize] = []
        var positions: [CGPoint] = []
        var containerSize: CGSize = .zero
        var lastWidth: CGFloat = 0
    }

    var spacing: CGFloat = 8

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: Array(repeating: .zero, count: subviews.count))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        self.arrangeSubviews(proposal: proposal, subviews: subviews, cache: &cache)
        return cache.containerSize
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        self.arrangeSubviews(proposal: proposal, subviews: subviews, cache: &cache)
        for (index, position) in cache.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrangeSubviews(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let proposedWidth = proposal.width ?? 0
        let maxWidth = proposedWidth > 0 ? proposedWidth : 260
        let needsLayout = cache.positions.count != subviews.count || cache.lastWidth != maxWidth

        if needsLayout {
            cache.positions = []
            cache.positions.reserveCapacity(subviews.count)
            cache.sizes = Array(repeating: .zero, count: subviews.count)
        }

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for index in subviews.indices {
            let size: CGSize
            if needsLayout {
                size = subviews[index].sizeThatFits(.unspecified)
                cache.sizes[index] = size
            } else {
                size = cache.sizes[index]
            }

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + self.spacing
                rowHeight = 0
            }
            if needsLayout {
                cache.positions.append(CGPoint(x: x, y: y))
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + self.spacing
        }

        cache.containerSize = CGSize(width: maxWidth, height: y + rowHeight)
        cache.lastWidth = maxWidth
    }
}

private extension SettingsView {
    var spokenSendSettings: some View {
        Group {
            self.optionToggleRow(
                title: "Spoken Send",
                description: "Say a phrase at the end of dictation to send with your chosen Enter command.",
                isOn: Binding(
                    get: { self.settings.spokenSendEnabled },
                    set: { self.settings.spokenSendEnabled = $0 }
                )
            )

            if self.settings.spokenSendEnabled {
                VStack(spacing: 10) {
                    self.optionToggleRow(
                        title: "Send Immediately",
                        description: "Stop listening and send as soon as the phrase is recognized. May not work with all voice models; Parakeet is recommended.",
                        isOn: Binding(
                            get: { self.settings.spokenSendImmediatelyEnabled },
                            set: { self.settings.spokenSendImmediatelyEnabled = $0 }
                        )
                    )

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Phrase")
                                .font(self.theme.typography.bodyStrong)
                                .foregroundStyle(self.settingsTitleText)
                            Text("Say it at the end. Say “literal \(self.settings.spokenSendPhrase)” to dictate it normally.")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        TextField(
                            "send it",
                            text: Binding(
                                get: { self.settings.spokenSendPhrase },
                                set: { self.settings.spokenSendPhrase = $0 }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 170)
                        .accessibilityLabel("Spoken Send phrase")
                    }

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send Command")
                                .font(self.theme.typography.bodyStrong)
                                .foregroundStyle(self.settingsTitleText)
                            Text("Choose the Enter behavior expected by the destination app.")
                                .font(self.theme.typography.bodySmall)
                                .foregroundStyle(self.settingsSecondaryText)
                                        .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer()

                        Picker("", selection: Binding(
                            get: { self.settings.spokenSendKey },
                            set: { self.settings.spokenSendKey = $0 }
                        )) {
                            ForEach(SettingsStore.SpokenSendKey.allCases) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 170, alignment: .trailing)
                        .accessibilityLabel("Spoken Send command")
                    }
                }
                .padding(.leading, 12)
            }
        }
    }
}

private struct DictionarySuggestionsSettingsRow: View {
    @Environment(\.theme) private var theme
    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Auto-Learn Corrections")
                    .font(self.theme.typography.bodyStrong)
                    .foregroundStyle(self.theme.palette.primaryText)
                Text("Suggest saving words after you correct dictated text.")
                    .font(self.theme.typography.bodySmall)
                    .foregroundStyle(self.theme.palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Suggest after", selection: self.$settings.automaticDictionarySuggestionFrequency) {
                ForEach(SettingsStore.AutomaticDictionarySuggestionFrequency.allCases) { frequency in
                    Text(frequency.displayName).tag(frequency)
                }
            }
            .labelsHidden()
            .frame(width: 138)
            .disabled(!self.settings.automaticDictionaryLearningEnabled)

            Toggle("", isOn: Binding(
                get: { self.settings.automaticDictionaryLearningEnabled },
                set: { enabled in
                    self.settings.automaticDictionaryLearningEnabled = enabled
                    if !enabled {
                        AutomaticDictionaryCorrectionTracker.shared.cancel()
                    }
                }
            ))
            .toggleStyle(.switch)
            .tint(self.theme.palette.accent)
            .labelsHidden()
        }
    }
}

// MARK: - Analytics modal confirmation

struct AnalyticsConfirmationView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.theme) private var theme

    private var contactInfoText: AttributedString {
        AttributedString("Use Feedback in VOCA to prepare a local report. No support service is connected in this preview.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stop sharing detailed anonymous analytics?")
                .font(.headline)

            Text("We never collect audio, transcription text, prompts, or other personal information.")
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(self.theme.palette.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(self.theme.palette.cardBorder.opacity(0.6), lineWidth: 1)
                )

            Text(self.contactInfoText)
                .font(self.theme.typography.bodySmall)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Divider()

            HStack {
                Spacer()

                Button("Cancel") {
                    self.onCancel()
                }

                Button("Stop Detailed Analytics") {
                    self.onConfirm()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

private struct VocaOverlayAppearancePreview: View {
    let showTranscript: Bool
    let atNotch: Bool
    var body: some View {
        VStack(spacing: 15) {
            HStack { Text("Appearance").font(.headline); Spacer(); Text("Preview").font(.caption).foregroundStyle(.secondary) }
            VStack(spacing: 9) {
                HStack(spacing: 12) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Applications/TextEdit.app"))
                        .resizable().frame(width: 22, height: 22).accessibilityLabel("TextEdit destination icon")
                    if atNotch { Spacer().frame(width: 100) }
                    HStack(spacing: 2.5) {
                        ForEach(0..<12) { i in
                            Capsule().fill(.white.opacity(0.9)).frame(width: 3, height: [8.0, 14, 22, 16, 28, 20, 25, 13, 21, 28, 16, 9][i])
                        }
                    }.frame(width: 70, height: 28)
                }.padding(.horizontal, 16).padding(.vertical, 10)
                    .background(atNotch ? Color.black : Color.clear, in: UnevenRoundedRectangle(topLeadingRadius: 6, bottomLeadingRadius: 22, bottomTrailingRadius: 22, topTrailingRadius: 6))
                    .vocaGlass(cornerRadius: atNotch ? 6 : 26).colorScheme(.dark)
                if showTranscript {
                    Text("A little space for your next thought.").font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 18).padding(.vertical, 12).vocaGlass(cornerRadius: 17)
                }
            }.frame(maxWidth: .infinity, minHeight: 116)
                .padding(20)
                .background(LinearGradient(colors: [Color(nsColor: .systemBlue).opacity(0.1), Color(nsColor: .systemBlue).opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
        }.padding(20)
    }
}
