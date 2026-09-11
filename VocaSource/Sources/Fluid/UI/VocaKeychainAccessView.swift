import SwiftUI

struct VocaKeychainAccessView: View {
    let onUnlocked: () -> Void
    @State private var unlocking = false
    @State private var status: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { self.explanation; Spacer(minLength: 0); self.unlockButton }
                VStack(alignment: .leading, spacing: 12) { self.explanation; self.unlockButton }
            }
            if let status { Text(status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
        }.padding(16).vocaContentSurface()
    }
    private var explanation: some View {
        Label("Saved keys stay in your Mac’s Keychain.", systemImage: "key.horizontal").font(.callout).foregroundStyle(.secondary)
    }
    private var unlockButton: some View {
        Button(self.unlocking ? "Waiting for Keychain…" : "Unlock saved API keys") {
            self.unlocking = true
            Task { @MainActor in
                defer { self.unlocking = false }
                do {
                    try await Task.detached(priority: .userInitiated) { try KeychainService.shared.requestAccess() }.value
                    SettingsStore.shared.resumeKeychainMigrations()
                    self.onUnlocked()
                    self.status = "Keychain access is ready."
                } catch {
                    self.status = "Keychain access was not granted. Your saved keys are unchanged. \(error.localizedDescription)"
                }
            }
        }.disabled(self.unlocking).fluidButton(.glass, size: .small)
    }
}
