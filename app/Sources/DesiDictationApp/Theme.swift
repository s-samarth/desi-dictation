import SwiftUI

/// The app's colors. Flat fills, no gradients or glows: color marks *meaning*
/// (which page, which language, what state), never decoration.
enum Theme {
    /// Saffron — the accent for switches, buttons and selection.
    static let accent = Color(red: 0.93, green: 0.45, blue: 0.13)

    static let hinglish = accent
    static let english = Color(red: 0.20, green: 0.47, blue: 0.95)
    static let hindi = Color(red: 0.13, green: 0.62, blue: 0.40)
    static let neutral = Color(red: 0.47, green: 0.50, blue: 0.55)

    /// A model's language, from its catalog category ("Hinglish", "English"…).
    static func color(forCategory category: String) -> Color {
        switch category {
        case "Hinglish": return hinglish
        case "English": return english
        case "हिन्दी": return hindi
        default: return neutral
        }
    }
}

extension SidebarItem {
    var tint: Color {
        switch self {
        case .dictation: return Theme.accent
        case .vocabulary: return Color(red: 0.56, green: 0.33, blue: 0.86)
        case .history: return Theme.english
        case .models: return Theme.hindi
        case .ai: return Color(red: 0.85, green: 0.25, blue: 0.45)
        case .license: return Theme.neutral
        }
    }
}

/// System Settings–style sidebar icon: white glyph on a flat colored tile.
struct IconTile: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(color, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

/// Small colored tag: a model's language, a dictation's mode.
struct Chip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// The shortcut key drawn as a keycap, so "hold Right ⌥" reads at a glance.
struct Keycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(.callout, design: .rounded).weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.secondary.opacity(0.6)))
    }
}
