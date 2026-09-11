import AppKit
import Combine
import ApplicationServices
import AVFoundation
import Speech
import SwiftUI

@MainActor final class VocaDestinationCheck: ObservableObject {
    @Published var selectedPID: pid_t = 0
    @Published private(set) var applications: [NSRunningApplication] = []
    @Published private(set) var status = "Choose an app, then place the cursor in a disposable draft."
    @Published private(set) var isChecking = false
    @Published private(set) var countdown = 0
    @Published private(set) var succeeded = false
    private var task: Task<Void, Never>?
    private let typing = TypingService()
    static let sample = "VOCA insertion check."

    func refresh() {
        self.applications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated
        }.sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        if !self.applications.contains(where: { $0.processIdentifier == self.selectedPID }) {
            self.selectedPID = self.applications.first?.processIdentifier ?? 0
        }
    }

    func cancel() {
        self.task?.cancel()
        self.task = nil
        self.isChecking = false
        self.countdown = 0
        self.status = "Check cancelled."
    }

    func start() {
        guard !self.isChecking else { return }
        guard AXIsProcessTrusted() else {
            self.status = "Allow VOCA in System Settings → Privacy & Security → Accessibility, then return here."
            return
        }
        guard let app = self.applications.first(where: { $0.processIdentifier == self.selectedPID }), !app.isTerminated else {
            self.status = "Open the app you want to check, then refresh the list."
            return
        }
        let chosenPID = self.selectedPID
        self.succeeded = false
        self.isChecking = true
        self.status = "Switching to \(app.localizedName ?? "your app"). Click a text field within 6 seconds."
        app.activate()
        self.task = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isChecking = false; self.countdown = 0 }
            do {
                for remaining in (1...6).reversed() {
                    self.countdown = remaining
                    try await Task.sleep(for: .seconds(1))
                }
                try Task.checkCancellation()
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == chosenPID,
                      let target = TypingService.captureSystemFocusTarget(), target.pid == chosenPID else {
                    self.status = "The selected app did not have focus. Start again and click inside its text field."
                    return
                }
                guard !target.isSecureTextField else {
                    self.status = "Password fields are protected. Choose a regular text field."
                    return
                }
                guard let before = VocaDestination.snapshot(target) else {
                    self.status = "This field does not expose its text and selection. Try a regular editable draft. Dictation may work here, but VOCA cannot verify it safely."
                    return
                }
                guard before.selection.length == 0 else {
                    self.status = "Some text is selected. Click to place a cursor so the check will not replace your words."
                    return
                }
                let outcome: TypingService.DeliveryOutcome = await withCheckedContinuation { continuation in
                    self.typing.typeOutputPlanInstantly(.plain(Self.sample), preferredTargetPID: chosenPID,
                        textReadyAt: nil, requiredFocusTarget: target) { continuation.resume(returning: $0) }
                }
                let expected = (before.value as NSString).replacingCharacters(in: before.selection, with: Self.sample)
                for _ in 0..<10 {
                    try await Task.sleep(for: .milliseconds(100))
                    if let value = VocaDestination.attribute(target.element, kAXValueAttribute) as? String, VocaDestination.exactPrefix(value, expected) {
                        self.succeeded = true
                        self.status = "Verified in \(app.localizedName ?? "your app"): the check text appeared at the cursor. You can undo the check below."
                        return
                    }
                }
                self.status = outcome.didInsert
                    ? "The insertion was sent, but this app did not confirm the expected text. Check the draft. Try Reliable Paste in Dictation settings if it is missing."
                    : "Insertion failed. Check Accessibility permission and select an editable field. If typing works manually, try Reliable Paste."
            } catch is CancellationError { self.status = "Check cancelled." }
            catch { self.status = error.localizedDescription }
        }
    }
}

struct VocaDestinationCheckView: View {
    @StateObject private var checker = VocaDestinationCheck()
    @ObservedObject private var recovery = VocaInsertionRecovery.shared
    @Environment(\.theme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @State private var trusted = AXIsProcessTrusted()
    @State private var speechAllowed = SFSpeechRecognizer.authorizationStatus() == .authorized
    @State private var microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "cursorarrow.rays").font(.system(size: 24)).foregroundStyle(self.theme.palette.accent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to write anywhere").font(.title3.weight(.semibold))
                    Text("Check permissions and try a real insertion in your app.").font(.callout).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 12) {
                self.permission("Insert at the cursor", allowed: self.trusted, symbol: "accessibility") {
                    VocaProduct.navigate("accessibility")
                }
                Divider()
                self.permission("Use the microphone", allowed: self.microphone, symbol: "mic") {
                    if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                        AVCaptureDevice.requestAccess(for: .audio) { _ in Task { @MainActor in self.refresh() } }
                    } else {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
                    }
                }
                if SettingsStore.shared.selectedSpeechModel == .appleSpeech {
                    Divider()
                    self.permission("Apple Speech Recognition", allowed: self.speechAllowed, symbol: "waveform") {
                        if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                            SFSpeechRecognizer.requestAuthorization { _ in Task { @MainActor in self.refresh() } }
                        } else {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!)
                        }
                    }
                }
            }
            if !self.trusted {
                Button("Show this VOCA build in Finder", systemImage: "folder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }.buttonStyle(.borderless).font(.caption)
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack { self.applicationPicker; self.checkButton }
                VStack(alignment: .leading, spacing: 12) { self.applicationPicker; self.checkButton }
            }
            Text("The check inserts “\(VocaDestinationCheck.sample)” after 6 seconds. Use an empty draft; nothing is submitted.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Label(self.checker.countdown > 0 ? "Click a text field · \(self.checker.countdown)s" : self.checker.status,
                  systemImage: self.checker.succeeded ? "checkmark.circle.fill" : "info.circle")
                .font(.callout).fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            VocaRecoveryView()
        }
        .padding(22).vocaContentSurface()
        .onAppear { self.refresh() }
        .onChange(of: self.scenePhase) { _, phase in if phase == .active { self.refresh() } }
        .onDisappear { if self.checker.isChecking { self.checker.cancel() } }
    }

    private var applicationPicker: some View {
        Picker("Destination", selection: self.$checker.selectedPID) {
            if self.checker.applications.isEmpty { Text("Open another app first").tag(pid_t(0)) }
            ForEach(self.checker.applications, id: \.processIdentifier) { app in
                Text(app.localizedName ?? "App").tag(app.processIdentifier)
            }
        }.disabled(self.checker.isChecking)
    }
    private var checkButton: some View {
        HStack(spacing: 8) {
            Button(self.checker.isChecking ? "Cancel" : "Check insertion") {
                self.checker.isChecking ? self.checker.cancel() : self.checker.start()
            }.fluidButton(.primary, size: .small).disabled(self.checker.selectedPID == 0)
            Button("Refresh", systemImage: "arrow.clockwise") { self.refresh() }
                .labelStyle(.iconOnly).help("Refresh permissions and apps").disabled(self.checker.isChecking)
        }.fixedSize()
    }
    private func permission(_ title: String, allowed: Bool, symbol: String, action: @escaping () -> Void) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer(minLength: 8)
            if allowed { Label("Allowed", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary) }
            else { Button("Set up", action: action).fluidButton(.glass, size: .small) }
        }
    }
    private func refresh() {
        self.trusted = AXIsProcessTrusted()
        self.speechAllowed = SFSpeechRecognizer.authorizationStatus() == .authorized
        self.microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        self.checker.refresh()
    }
}

struct VocaRecoveryView: View {
    @ObservedObject private var recovery = VocaInsertionRecovery.shared
    var body: some View {
        DisclosureGroup("Last insertion & recovery") {
            VStack(alignment: .leading, spacing: 12) {
                Text(self.recovery.message).font(.callout).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Undo insertion", systemImage: "arrow.uturn.backward") { self.recovery.undo() }
                        .disabled(self.recovery.receipt == nil)
                    Button("Copy words", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(self.recovery.recoveryText, forType: .string)
                    }.disabled(self.recovery.recoveryText.isEmpty)
                }
                if !self.recovery.recoveryText.isEmpty {
                    Text(self.recovery.recoveryText).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(5).textSelection(.enabled)
                }
            }.padding(.top, 12)
        }.font(.callout.weight(.medium))
    }
}
