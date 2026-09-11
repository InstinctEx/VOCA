import SwiftUI

struct VocaAutoFinishSettings: View {
    @AppStorage("voca.autoFinish.enabled") private var enabled = false
    @AppStorage("voca.autoFinish.pause") private var pause = 12.0
    @ObservedObject private var autoFinish = VocaAutoFinish.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Finish after a pause", isOn: $enabled)
            Text("Room to think. Automatic finish starts only after speech, waits through a pause, then gives you a 3-second countdown. Speaking again resets it.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if enabled {
                Picker("Thinking time", selection: $pause) {
                    Text("Quick · 3 seconds").tag(3.0)
                    Text("Balanced · 7 seconds").tag(7.0)
                    Text("Thoughtful · 12 seconds").tag(12.0)
                }
                Text("Toggle-mode dictation only. An unfinished English phrase gets extra time. This detects quiet, not intent; background voices can keep it listening. It never presses Send.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if autoFinish.countdown != nil {
                Button("Keep listening for this recording") { autoFinish.keepListening() }
            }
        }.padding(18).vocaContentSurface()
    }
}

struct VocaCleanupHealthView: View {
    @ObservedObject private var monitor = VocaCleanupMonitor.shared
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(monitor.slow ? "Cleanup is taking a while" : "A little less waiting", systemImage: monitor.slow ? "clock.badge.exclamationmark" : "bolt")
                .font(.headline)
            Text(monitor.running ? "\(monitor.label) is working. After 30 seconds, VOCA falls back to your original words." : monitor.lastResult)
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if monitor.slow || monitor.lastSeconds >= 8 {
                Text("Try a smaller model, keep your local model loaded, or choose another provider. Your recording does not need to be repeated.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if monitor.running { Button("Use original words now") { monitor.useOriginal() } }
        }.padding(18).vocaContentSurface()
    }
}

struct VocaPauseCountdown: View {
    @ObservedObject private var autoFinish = VocaAutoFinish.shared
    var body: some View {
        if let seconds = autoFinish.countdown {
            Button { autoFinish.keepListening() } label: {
                Text("\(seconds)").font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                    .frame(width: 28, height: 28).background(.white.opacity(0.15), in: Circle())
            }.buttonStyle(.plain).foregroundStyle(.white)
                .accessibilityLabel("Finishing in \(seconds) seconds. Keep listening")
                .help("Keep listening for this recording")
        }
    }
}
