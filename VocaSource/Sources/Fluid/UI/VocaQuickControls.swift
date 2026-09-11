import AppKit
import SwiftUI

struct VocaQuickControls: View {
    @EnvironmentObject private var services: AppServices
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var cleanup = VocaCleanupMonitor.shared
    @State private var inputs: [AudioDevice.Device] = []
    @State private var changingModel = false
    @State private var status = "Changes apply to your next dictation."

    private var busy: Bool {
        self.changingModel || self.cleanup.running || self.services.asr.isRunningOrStarting || self.services.asr.isBenchmarking
            || self.services.asr.hasActiveModelDownload || self.services.asr.hasActiveModelPreparation
    }
    private var styleBinding: Binding<String> {
        Binding(get: {
            switch self.settings.dictationPromptSelection {
            case .off: return "off"
            case .default: return "default"
            case .privateAI: return "private"
            case let .profile(id): return id
            }
        }, set: { value in
            switch value {
            case "off": self.settings.setDictationPromptSelection(.off)
            case "default": self.settings.setDictationPromptSelection(.default)
            case "private": self.settings.setDictationPromptSelection(.privateAI)
            default: self.settings.setDictationPromptSelection(.profile(value))
            }
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Label("Quick Controls", systemImage: "slider.horizontal.3").font(.title2.weight(.semibold))
                Spacer()
                Button("Done") { self.dismiss() }.keyboardShortcut(.cancelAction)
            }
            VStack(spacing: 18) {
                Picker("Speech model", selection: Binding(get: { self.settings.selectedSpeechModel }, set: self.selectModel)) {
                    ForEach(SettingsStore.SpeechModel.availableModels.filter { $0.isInstalled || $0 == self.settings.selectedSpeechModel }) { model in
                        Text(model.displayName).tag(model)
                    }
                }
                Divider()
                Picker("Microphone", selection: Binding(get: { self.settings.microphonePriority.first?.uid ?? "" }, set: { uid in
                    guard let device = self.inputs.first(where: { $0.uid == uid }) else { return }
                    self.settings.recordInputDeviceSelection(uid, name: device.name)
                })) {
                    if let preferred = self.settings.microphonePriority.first, !self.inputs.contains(where: { $0.uid == preferred.uid }) {
                        Text("\(preferred.name) · Disconnected").tag(preferred.uid)
                    } else if self.inputs.isEmpty { Text("No microphone connected").tag("") }
                    ForEach(self.inputs, id: \.uid) { device in Text(device.name).tag(device.uid) }
                }
                Divider()
                Picker("Writing style", selection: self.styleBinding) {
                    Text("As spoken · No cleanup").tag("off")
                    Text("Everyday").tag("default")
                    if PrivateAIProviderPromptFormat.isAvailable(settings: self.settings) {
                        Text("Local cleanup").tag("private")
                    }
                    ForEach(self.settings.promptProfiles(for: .dictate)) { profile in Text(profile.name).tag(profile.id) }
                }
            }.disabled(self.busy).padding(20).vocaContentSurface()
            if self.busy { ProgressView("Finish the current operation to change controls.").controlSize(.small) }
            Text(self.status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Text("Tab moves between controls. Arrow keys choose an option. Escape closes. Per-app styles and dedicated shortcuts still take precedence.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if self.cleanup.running || self.cleanup.lastSeconds >= 8 { VocaCleanupHealthView() }
            VocaRecoveryView()
            HStack {
                Button("More models") { self.dismiss(); VocaProduct.navigate("models") }
                Button("Check a destination") { self.dismiss(); VocaProduct.navigate("destination") }
            }.buttonStyle(.borderless).font(.callout)
        }.padding(24).frame(width: 460).background(self.theme.palette.windowBackground).vocaMotionPolicy()
            .onAppear { self.inputs = AudioDevice.listInputDevices() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                self.inputs = AudioDevice.listInputDevices()
            }
    }

    private func selectModel(_ model: SettingsStore.SpeechModel) {
        guard !self.busy, model != self.settings.selectedSpeechModel, model.isInstalled else { return }
        self.changingModel = true
        self.settings.selectedSpeechModel = model
        self.services.asr.resetTranscriptionProvider()
        Task { @MainActor in
            defer { self.changingModel = false }
            do {
                try await self.services.asr.ensureAsrReady(source: .settings)
                self.status = "\(model.displayName) is ready."
            } catch { self.status = "Could not prepare this model: \(error.localizedDescription)" }
        }
    }
}
