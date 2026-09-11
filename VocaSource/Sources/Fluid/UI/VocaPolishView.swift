import SwiftUI
import Combine

@MainActor final class VocaPolishControl: ObservableObject {
    static let shared = VocaPolishControl()
    @Published var installed = VocaPolishFiles.installed()
    @Published var busy = false
    @Published var downloading = false
    @Published var message = "Download once. Your words stay on this Mac."
    @Published var progress: PrivateAIModelDownloadProgress?
    @Published var output = ""
    @Published var seconds: Double?
    private var task: Task<Void, Never>?
    private var operationID: UUID?
    func download(verify: @escaping @MainActor () async -> Bool) {
        guard !busy else { return }
        busy = true; downloading = true; message = "Preparing download…"
        let id = UUID(); operationID = id
        task = Task {
            do {
                _ = try await VocaPolishDownloads.shared.prepare { [weak self] value in
                    await MainActor.run {
                        guard self?.operationID == id, self?.downloading == true else { return }
                        if value.totalBytesWritten >= (self?.progress?.totalBytesWritten ?? 0) { self?.progress = value }
                    }
                }
                try Task.checkCancellation()
                downloading = false; installed = true; message = "Checking the model on this Mac…"
                let success = await verify()
                message = success ? "Ready. Select VOCA Polish as your enhancement provider." : "Downloaded. Verification failed; try Load & verify."
            } catch { message = Task.isCancelled ? "Download paused. Resume keeps completed files and partial bytes." : error.localizedDescription }
            busy = false; downloading = false; task = nil; operationID = nil
        }
    }
    func cancel() { task?.cancel(); message = "Pausing…" }
    func test(_ text: String, style: String) {
        guard !busy else { return }
        busy = true; output = ""; seconds = nil; message = "Polishing on this Mac…"
        task = Task {
            do {
                let result = try await VocaPolishEngine.shared.generate(text, style: style)
                output = result.outputText
                seconds = Double(result.latencyMilliseconds ?? 0) / 1000
                message = "Finished locally in \(String(format: "%.2f", seconds ?? 0))s."
            } catch { message = Task.isCancelled ? "Canceled. Your sample was not changed." : error.localizedDescription }
            busy = false; task = nil
        }
    }
    func remove() {
        guard !busy else { return }
        busy = true
        task = Task {
            do { try await VocaPolishDownloads.shared.delete(); installed = false; progress = nil; output = ""; message = "Model removed. You can download it again any time." }
            catch { message = error.localizedDescription }
            busy = false; task = nil
        }
    }
}

struct VocaPolishView: View {
    @ObservedObject private var control = VocaPolishControl.shared
    @AppStorage("voca.polish.keepWarm") private var keepWarm = false
    @State private var sample = "hey Alex um can we move our meeting to 3 pm tomorrow thanks"
    @State private var style = VocaPolishPrompt.defaultStyle
    @State private var showDelete = false
    let verify: @MainActor () async -> Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("A little polish. Entirely on your Mac.", systemImage: "sparkles").font(.headline)
            Text("Qwen3 4B Instruct · 4-bit · \(ByteCountFormatter.string(fromByteCount: VocaPolishFiles.totalBytes, countStyle: .file)) download")
                .font(.callout).foregroundStyle(.secondary)
            Text("No API key or companion app. Apple Silicon required; 16 GB memory recommended alongside speech recognition.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if control.downloading {
                ProgressView(value: control.progress?.fractionCompleted ?? 0).accessibilityLabel("Model download progress")
                Text(PrivateAIModelDownloadProgressText.detailText(for: control.progress)).font(.caption).monospacedDigit()
            }
            Text(control.message).font(.callout).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            HStack {
                if control.busy { ProgressView().controlSize(.small); Button(control.downloading ? "Pause download" : "Cancel") { control.cancel() } }
                else if !control.installed { Button(control.progress == nil ? "Download VOCA Polish" : "Resume download") { control.download(verify: verify) }.buttonStyle(.borderedProminent) }
                else {
                    Button("Load & verify") { control.download(verify: verify) }
                    Button("Free memory") { Task { await VocaPolishEngine.shared.unload(); control.message = "Memory release requested. The next dictation reloads the model." } }
                    Button("Delete model…", role: .destructive) { showDelete = true }
                }
            }
            Toggle("Keep ready between dictations", isOn: $keepWarm)
            Text(keepWarm ? "Keeps weights loaded for up to 10 idle minutes. Memory pressure still releases them." : "Releases weights after one idle minute. The next cleanup may take longer to start.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if control.installed {
                DisclosureGroup("Try it on your words") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("This test only shows a result here. It does not type into another app.").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $sample).font(.body).frame(height: 90).accessibilityLabel("Local enhancement sample")
                        TextField("Writing instructions", text: $style, axis: .vertical).lineLimit(2...4)
                        Button("Polish sample") { control.test(sample, style: style) }.disabled(control.busy || sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !control.output.isEmpty { Text(control.output).textSelection(.enabled).padding(12).frame(maxWidth: .infinity, alignment: .leading).vocaContentSurface() }
                    }.padding(.top, 10)
                }
            }
            Link("Model credits & Apache 2.0 license", destination: URL(string: "https://huggingface.co/Qwen/Qwen3-4B-Instruct-2507")!).font(.caption)
        }
        .confirmationDialog("Delete downloaded VOCA Polish files?", isPresented: $showDelete) {
            Button("Delete model", role: .destructive) { control.remove() }
        } message: { Text("Your writing styles stay saved. Using local enhancement again requires a new download.") }
    }
}
