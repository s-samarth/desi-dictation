import SwiftUI

/// Building blocks shared by setup's pages, so every page has the same
/// title size, card shape and spacing.

/// A page's title and one plain sentence under it.
struct StepTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).font(.title3).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A rounded panel, edged in `tint` when selected (saffron for a choice,
/// green for a granted permission).
struct CardBackground: ViewModifier {
    var selected = false
    var tint = Theme.accent

    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? tint.opacity(0.10) : Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? tint : Color.primary.opacity(0.10),
                              lineWidth: selected ? 2 : 1))
    }
}

extension View {
    func card(selected: Bool = false, tint: Color = Theme.accent) -> some View {
        modifier(CardBackground(selected: selected, tint: tint))
    }
}

/// A whole card you click to choose: icon, name, a line on what it is, and
/// an optional tag ("Default", "Most accurate").
struct ChoiceCard<Trailing: View>: View {
    let symbol: String
    let title: String
    let detail: String
    var tag: String?
    let selected: Bool
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2).foregroundStyle(selected ? Theme.accent : .secondary)
                Image(systemName: symbol).font(.title2).frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title).font(.title3.weight(.semibold))
                        if let tag { Chip(text: tag, color: Theme.accent) }
                    }
                    Text(detail).font(.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                trailing()
            }
            .card(selected: selected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

extension ChoiceCard where Trailing == EmptyView {
    init(symbol: String, title: String, detail: String, tag: String? = nil,
         selected: Bool, action: @escaping () -> Void) {
        self.init(symbol: symbol, title: title, detail: detail, tag: tag,
                  selected: selected, action: action) { EmptyView() }
    }
}

/// An optional feature: what it does, an example, and who should turn it on.
struct FeatureCard: View {
    let symbol: String
    let title: String
    let what: String
    let turnOnIf: String
    @Binding var isOn: Bool
    var enabled = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                Text(what).font(.body).fixedSize(horizontal: false, vertical: true)
                Label(turnOnIf, systemImage: "lightbulb")
                    .font(.body).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn).toggleStyle(.switch).labelsHidden().disabled(!enabled)
        }
        .card(selected: isOn)
        .opacity(enabled ? 1 : 0.5)
    }
}

/// A tip in a tinted box, for the one thing on a page worth remembering.
struct Tip: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Theme.accent)
            Text(text).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// Setup's progress bar: one segment per page after the welcome.
struct StepProgress: View {
    let current: OnboardingModel.Step

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingModel.Step.allCases.dropFirst(), id: \.self) { step in
                VStack(alignment: .leading, spacing: 4) {
                    Capsule()
                        .fill(step.rawValue <= current.rawValue ? Theme.accent : Color.primary.opacity(0.12))
                        .frame(height: 4)
                    Text(step.label)
                        .font(.caption.weight(step == current ? .semibold : .regular))
                        .foregroundStyle(step == current ? .primary : .secondary)
                }
            }
        }
    }
}
