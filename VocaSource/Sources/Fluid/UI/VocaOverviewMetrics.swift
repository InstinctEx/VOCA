import SwiftUI

/// Overview uses retained history; estimates are explicitly labeled, never invented activity.
struct VocaOverviewMetrics: View {
    @ObservedObject private var history = TranscriptionHistoryStore.shared
    @ObservedObject private var settings = SettingsStore.shared
    var openUsage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("A little more time for you").font(.headline)
                Spacer()
                Button("View activity", systemImage: "arrow.up.right", action: self.openUsage)
                    .buttonStyle(.borderless).font(.caption)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) { self.savedTime.frame(width: 190); self.metrics }
                VStack(alignment: .leading, spacing: 14) { self.savedTime; self.metrics }
            }
            HStack(spacing: 6) {
                Image(systemName: "lock")
                Text("Pace includes pauses and updates after each saved dictation. Time saved compares \(self.settings.userTypingWPM) typing WPM with recording and processing time. Older untimed entries use a 150 WPM estimate.")
            }.font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var savedTime: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Estimated time saved", systemImage: "hourglass").font(.callout).foregroundStyle(.secondary)
            Text(self.history.totalWords == 0 ? "0m" : self.history.formattedTimeSaved(typingWPM: self.settings.userTypingWPM))
                .font(.system(size: 42, weight: .semibold)).monospacedDigit()
            let days = self.history.dailyWordCounts(days: 7)
            let peak = max(1, days.map(\.words).max() ?? 1)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days, id: \.date) { day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(day.words > 0 ? Color.accentColor.opacity(0.7) : Color.secondary.opacity(0.2))
                            .frame(height: max(3, 38 * CGFloat(day.words) / CGFloat(peak)))
                        Text(day.date, format: .dateTime.weekday(.narrow)).font(.system(size: 10)).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.words) words")
                }
            }.frame(height: 54, alignment: .bottom)
            Text("Last 7 days").font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).vocaContentSurface()
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            self.metric("Words dictated", value: self.history.totalWords.formatted(), symbol: "text.alignleft")
            self.metric("Dictations", value: self.history.entries.count.formatted(), symbol: "waveform")
            self.metric("Speaking pace · WPM", value: self.history.dictationMetrics.speakingWPM.map { String(Int($0.rounded())) } ?? "—", symbol: "speedometer")
            self.metric("Time dictating", value: self.history.dictationMetrics.measuredSessions > 0 ? "\(Int(self.history.dictationMetrics.recordingSeconds / 60))m \(Int(self.history.dictationMetrics.recordingSeconds) % 60)s" : "—", symbol: "mic")
        }.frame(minWidth: 220)
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.secondary)
            Text(value).font(.system(size: 24, weight: .semibold)).monospacedDigit()
            Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(16).vocaContentSurface()
    }
}
