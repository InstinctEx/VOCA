import SwiftUI

/// Local, explainable style signals. Raw examples never become prompt content.
enum VocaPersonalStyle {
    struct Analysis: Equatable {
        let traits: [String]
        let prompt: String
        let wordCount: Int
    }
    static func analyze(_ input: String) -> Analysis? {
        let bounded = String(input.prefix(20_000))
        let words = bounded.split(whereSeparator: \.isWhitespace)
        guard words.count >= 80 else { return nil }
        let sentences = bounded.split(whereSeparator: { ".!?".contains($0) }).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let average = Double(words.count) / Double(max(1, sentences.count))
        let letters = bounded.filter(\.isLetter)
        let uppercaseRatio = Double(letters.filter(\.isUppercase).count) / Double(max(1, letters.count))
        let paragraphs = bounded.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var traits = [average < 15 ? "Prefer short, direct sentences." : average > 28 ? "Allow longer, flowing sentences when the meaning stays clear." : "Use a mix of short and medium-length sentences."]
        if uppercaseRatio < 0.005 { traits.append("Prefer lowercase casual prose; keep proper names, acronyms, and code intact.") }
        if paragraphs.count >= 3 { traits.append("Use short paragraphs with clear breaks between ideas.") }
        if bounded.contains("'") || bounded.contains("’") { traits.append("Use natural contractions when appropriate.") }
        if bounded.contains("—") { traits.append("An occasional em dash is welcome; avoid overusing it.") }
        if bounded.components(separatedBy: "\n").filter({ $0.hasPrefix("- ") || $0.hasPrefix("• ") }).count >= 2 {
            traits.append("Use bullets for lists or separate action items.")
        }
        let prompt = "Clean up my dictation in my personal writing style. Preserve my meaning, facts, names, numbers, and level of certainty. Never answer questions or invent details. Apply these locally observed preferences when appropriate:\n" + traits.map { "- " + $0 }.joined(separator: "\n") + "\nDo not force a preference where it changes the meaning. Return only the revised text."
        return Analysis(traits: traits, prompt: prompt, wordCount: words.count)
    }
}

struct VocaPersonalStyleView: View {
    let create: (String) -> Void
    @State private var expanded = false
    @State private var examples = ""
    @State private var analysis: VocaPersonalStyle.Analysis?
    @State private var message = ""
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Paste a few things you wrote—at least 80 words. VOCA estimates sentence length, punctuation, and paragraph habits on this Mac. These examples are not sent to an AI or saved as part of the style.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                TextEditor(text: $examples).font(.body).frame(height: 150).scrollContentBackground(.hidden)
                    .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Your writing examples")
                    .onChange(of: examples) { _, value in
                        if value.count > 20_000 { examples = String(value.prefix(20_000)) }
                        analysis = nil
                    }
                HStack {
                    Button("Find my style") {
                        analysis = VocaPersonalStyle.analyze(examples)
                        message = analysis == nil ? "Add at least 80 words for a useful starting point." : "A starting point, not a personality test. Review before saving."
                    }.disabled(examples.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Clear examples") { examples = ""; analysis = nil; message = "" }
                    Spacer()
                    Text("\(examples.split(whereSeparator: \.isWhitespace).count) words").font(.caption).foregroundStyle(.secondary)
                }
                if !message.isEmpty { Text(message).font(.caption).foregroundStyle(.secondary) }
                if let analysis {
                    ForEach(analysis.traits, id: \.self) { Text("• " + $0).font(.callout) }
                    Button("Review my personal style") { create(analysis.prompt); examples = ""; self.analysis = nil }
                    Text("The saved style is a normal editable prompt. Your chosen cleanup provider receives those instructions with future dictations.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.padding(.top, 14)
        } label: {
            Label("Sounds like me", systemImage: "person.text.rectangle").font(.headline)
        }.padding(18).vocaContentSurface()
    }
}
