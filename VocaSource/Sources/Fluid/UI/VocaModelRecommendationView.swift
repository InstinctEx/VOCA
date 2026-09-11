import SwiftUI

struct VocaModelRecommendationView: View {
    @ObservedObject private var advisor = VocaModelAdvisor.shared
    @ObservedObject var viewModel: VoiceEngineSettingsViewModel
    @State private var benchmarkMessage: String?
    @State private var timingModel = false

    var body: some View {
        DisclosureGroup("Find a model for this Mac") {
            VStack(alignment: .leading, spacing: 14) {
                Text(self.advisor.description).font(.callout)
                if let measurement = self.advisor.measurement {
                    Text(measurement).font(.caption.monospacedDigit()).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if self.advisor.isRunning || self.timingModel { ProgressView().controlSize(.small) }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { self.actions }
                    VStack(alignment: .leading, spacing: 12) { self.actions }
                }
                if let benchmarkMessage { Text(benchmarkMessage).font(.callout).textSelection(.enabled) }
                Text("The recommendation uses memory and a measured Accelerate compute test. It is a starting point, not a speech-accuracy score. Timing uses a bundled speech sample with your selected local model; no microphone, history, or cloud request is used.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(.top, 14)
        }.font(.callout.weight(.medium)).padding(20).vocaContentSurface()
            .onDisappear { if self.timingModel { self.viewModel.asr.cancelVocaSpeechBenchmark() } }
    }

    @ViewBuilder private var actions: some View {
        Button(self.advisor.recommendation == nil ? "Check this Mac" : "Check again") { Task { await self.advisor.run() } }
            .disabled(self.advisor.isRunning || self.viewModel.areSpeechModelActionsBlocked)
        if let model = self.advisor.recommendation {
            Button(model.isInstalled ? "Use \(model.displayName)" : "Download \(model.displayName)") {
                model.isInstalled ? self.viewModel.activateSpeechModel(model) : self.viewModel.downloadSpeechModel(model)
            }.disabled(self.viewModel.areSpeechModelActionsBlocked)
        }
        if self.timingModel {
            Button("Stop timing") {
                self.viewModel.asr.cancelVocaSpeechBenchmark()
                self.benchmarkMessage = "Stopping after the current model run…"
            }
        } else {
        Button("Time selected model") {
            self.timingModel = true
            Task { @MainActor in
                defer { self.timingModel = false }
                do { self.benchmarkMessage = try await self.viewModel.asr.runVocaSpeechBenchmark() }
                catch is CancellationError { self.benchmarkMessage = "Timing cancelled." }
                catch { self.benchmarkMessage = error.localizedDescription }
            }
        }.disabled(self.viewModel.areSpeechModelActionsBlocked || self.timingModel || self.viewModel.settings.selectedSpeechModel.provider == .apple || !self.viewModel.settings.selectedSpeechModel.isInstalled)
        }
    }
}
