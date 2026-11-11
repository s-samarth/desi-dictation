import SwiftUI
import DesiDictationKit

/// Underline colours: orange for words the model wasn't sure of, purple for
/// words odd in their sentence, blue for "which spelling is yours?".
extension ReviewTextView {
    static func color(for reason: UnsureWord.Reason) -> NSColor {
        switch reason {
        case .odd: return .systemPurple
        case .spelling: return .systemBlue
        default: return NSColor(Theme.accent)
        }
    }
}

/// Hinglish Learning (HINGLISH_LEARNING.md): a habit the user's fixes show,
/// offered as one rule for every Hindi word. Yes adopts it, No stops asking,
/// no answer asks again next time.
struct LearningHabitRows: View {
    @ObservedObject var model: ReviewModel

    var body: some View {
        ForEach(model.habits, id: \.self) { habit in
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(.blue)
                Text(habit.question).font(.callout)
                Spacer()
                Picker("", selection: Binding(
                    get: { model.habitAnswers[habit] },
                    set: { model.habitAnswers[habit] = $0 })) {
                    Text("Yes").tag(Bool?.some(true))
                    Text("No").tag(Bool?.some(false))
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 110)
            }
        }
    }
}

/// After enough clean Hinglish dictations: offer to stop opening every time.
struct LearningDoneBanner: View {
    @ObservedObject var model: ReviewModel
    @ObservedObject var learning = HinglishLearning.shared

    var body: some View {
        if model.request.learning, learning.isDone {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.hindi)
                Text("\(HinglishLearning.graduateAfter) Hinglish dictations in a row without a fix. It knows your spellings now.")
                    .font(.callout)
                Spacer()
                Button("Keep learning") { learning.keepLearning() }
                Button("Stop learning") { learning.stopLearning() }
                    .buttonStyle(.borderedProminent)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.hindi.opacity(0.12)))
        }
    }
}
