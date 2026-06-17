import NaturalLanguage
import SwiftUI

/// On-device text analysis: dominant-language detection, sentiment scoring, and
/// part-of-speech tagging — all from the `NaturalLanguage` framework, no model
/// files or network.
struct NaturalLanguageView: View {
    @State private var text = "I absolutely love how much my new iPhone can do — it's incredible!"

    var body: some View {
        Form {
            Section("Your text") {
                TextEditor(text: $text).frame(minHeight: 90)
            }

            Section("Detected language") {
                LabeledContent("Language", value: analysis.languageName)
                LabeledContent("Code", value: analysis.languageCode)
            }

            Section("Sentiment") {
                HStack {
                    Text(analysis.sentimentEmoji).font(.title)
                    VStack(alignment: .leading) {
                        Text(analysis.sentimentLabel).font(.headline)
                        Text(String(format: "score %.2f  (−1 … +1)", analysis.sentiment))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Parts of speech") {
                if analysis.tokens.isEmpty {
                    Text("—").foregroundStyle(.secondary)
                } else {
                    FlowTags(tokens: analysis.tokens)
                }
            }
        }
        .navigationTitle("Natural Language")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var analysis: NLAnalysis { NLAnalysis(text: text) }
}

/// Wraps the part-of-speech chips so they flow onto multiple lines.
private struct FlowTags: View {
    let tokens: [(word: String, tag: String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tokens.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    Text(tokens[i].word).font(.callout.weight(.medium))
                    Text(tokens[i].tag).font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
            }
        }
    }
}

/// Pure-value analysis recomputed as the text changes.
private struct NLAnalysis {
    let languageName: String
    let languageCode: String
    let sentiment: Double
    let tokens: [(word: String, tag: String)]

    init(text: String) {
        // Language
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let lang = recognizer.dominantLanguage {
            languageCode = lang.rawValue
            languageName = Locale.current.localizedString(forIdentifier: lang.rawValue) ?? lang.rawValue
        } else {
            languageCode = "—"; languageName = "Unknown"
        }

        // Sentiment
        let sentTagger = NLTagger(tagSchemes: [.sentimentScore])
        sentTagger.string = text
        let (sentTag, _) = sentTagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        sentiment = Double(sentTag?.rawValue ?? "0") ?? 0

        // Part of speech (first ~12 words)
        var collected: [(String, String)] = []
        let posTagger = NLTagger(tagSchemes: [.lexicalClass])
        posTagger.string = text
        posTagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word,
                                scheme: .lexicalClass,
                                options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            if let tag { collected.append((String(text[range]), tag.rawValue)) }
            return collected.count < 12
        }
        tokens = collected.map { (word: $0.0, tag: $0.1) }
    }

    var sentimentLabel: String {
        switch sentiment {
        case let s where s > 0.25: return "Positive"
        case let s where s < -0.25: return "Negative"
        default: return "Neutral"
        }
    }
    var sentimentEmoji: String {
        switch sentiment {
        case let s where s > 0.25: return "😀"
        case let s where s < -0.25: return "☹️"
        default: return "😐"
        }
    }
}
