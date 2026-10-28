import SwiftUI

/// One feature, explained the same way every time: what it does, how it
/// plays out step by step, when it's worth turning on and when not — with
/// the switch right there, so reading and deciding happen in one place.
struct GuideFeature: View {
    let number: Int
    let title: String
    let summary: String
    var steps: [String] = []
    var turnOnIf: String?
    var skipIf: String?
    var isOn: Binding<Bool>?
    var disabledNote: String?
    /// A picture of the feature in action, under the summary.
    var example: AnyView?

    var body: some View {
        Section {
            Text(summary)
            if let example { example }
            if !steps.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
                                .frame(width: 16)
                            Text(.init(step)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            if let turnOnIf {
                verdict("checkmark.circle.fill", Theme.hindi, "Turn on if", turnOnIf)
            }
            if let skipIf {
                verdict("minus.circle.fill", Theme.neutral, "Leave off if", skipIf)
            }
            if let isOn {
                Toggle(isOn: isOn) {
                    Text(isOn.wrappedValue ? "On" : "Off").fontWeight(.semibold)
                    if let disabledNote { Text(disabledNote) }
                }
                .disabled(disabledNote != nil)
            }
        } header: {
            HStack(spacing: 8) {
                Text("\(number)")
                    .font(.caption.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Theme.accent, in: Circle())
                Text(title).font(.headline)
            }
        }
    }

    private func verdict(_ symbol: String, _ color: Color, _ label: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            (Text(label + ": ").fontWeight(.semibold) + Text(text))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// The "Rowan → Rohan" example drawn out: what you dictated, what you fixed,
/// what it asks. Seeing the popup's words is what makes the feature click.
struct LearnExample: View {
    var body: some View {
        HStack(spacing: 10) {
            bubble("You dictate", "Call **Rowan** at 5")
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            bubble("You fix it in the text", "Call **Rohan** at 5")
            Image(systemName: "arrow.right").foregroundStyle(.tertiary)
            bubble("It asks", "Always write Rowan as **Rohan**?", tint: Theme.accent)
        }
        .padding(.vertical, 4)
    }

    private func bubble(_ caption: String, _ text: String, tint: Color = Theme.neutral) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption).font(.caption).foregroundStyle(.secondary)
            Text(.init(text)).font(.callout)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(tint.opacity(0.5)))
        }
    }
}
