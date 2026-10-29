import SwiftUI
import DesiDictationKit

/// The review panel's content: the text with unsure words underlined, the
/// choices for the word at the caret, and what to remember.
struct ReviewView: View {
    @ObservedObject var model: ReviewModel

    static let width: CGFloat = 560

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ReviewTextEditor(model: model)
                .frame(minHeight: 70, maxHeight: 160)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.neutral.opacity(0.25)))
            alternatives
            if model.canRemember, !model.fixes.isEmpty { remember }
            footer
        }
        .padding(16)
        .frame(width: Self.width)
        .tint(Theme.accent)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Check before pasting").font(.headline)
            Spacer()
            Text(model.request.unsure.isEmpty ? "Nothing looked unsure"
                 : "\(model.request.unsure.count) unsure \(model.request.unsure.count == 1 ? "word" : "words")")
                .font(.caption).foregroundStyle(model.request.unsure.isEmpty ? Theme.hindi : Theme.accent)
        }
    }

    @ViewBuilder private var alternatives: some View {
        if let current = model.current {
            HStack(spacing: 6) {
                Text(current.confidence == nil ? "Sounds like:" : "Maybe:")
                    .font(.caption).foregroundStyle(.secondary)
                if current.alternatives.isEmpty {
                    Text("no suggestions; type the right word")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(current.alternatives.enumerated()), id: \.offset) { n, word in
                    Button { model.pick?(n) } label: {
                        HStack(spacing: 4) {
                            Keycap(label: "\(n + 1)")
                            Text(word)
                        }
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                }
                Spacer()
            }
        } else {
            Text(model.request.unsure.isEmpty ? "Edit anything, then press Enter."
                 : "Tab goes to the next underlined word.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var remember: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remember your fixes?").font(.caption.weight(.semibold))
            ForEach($model.fixes) { $fix in
                HStack {
                    Text(fix.pair.heard).strikethrough().foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                    Text(fix.pair.typed).fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $fix.keep) {
                        ForEach(model.keepChoices) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 290)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("Tab next · 1–\(ReviewAlternatives.limit) pick · Esc copies instead")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Copy") { model.finish(paste: false) }
            Button("Paste") { model.finish(paste: true) }
                .buttonStyle(.borderedProminent)
        }
    }
}
