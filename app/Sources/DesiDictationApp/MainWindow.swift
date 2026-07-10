import SwiftUI
import DesiDictationKit

/// The main app window (MacWhisper-style sidebar layout). The menu bar icon is
/// for quick toggles; this window is where users actually configure things —
/// added after v0.1 feedback that a bare menu bar icon felt undiscoverable.
enum SidebarItem: String, CaseIterable, Identifiable {
    case dictation, history, models, text, ai, license
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: return "Dictation"
        case .history: return "History"
        case .models: return "Models"
        case .text: return "Text"
        case .ai: return "AI"
        case .license: return "License"
        }
    }

    var icon: String {
        switch self {
        case .dictation: return "mic"
        case .history: return "clock.arrow.circlepath"
        case .models: return "cpu"
        case .text: return "character.cursor.ibeam"
        case .ai: return "sparkles"
        case .license: return "key"
        }
    }
}

/// Sidebar selection, reachable from outside the view hierarchy (menu items
/// deep-link straight to a pane — e.g. "Finish AI setup" → the AI pane).
@MainActor
final class MainNav: ObservableObject {
    static let shared = MainNav()
    @Published var selection: SidebarItem = .dictation
}

struct MainWindow: View {
    @ObservedObject private var nav = MainNav.shared

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: Binding(
                get: { Optional(nav.selection) },
                set: { nav.selection = $0 ?? .dictation })) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 180)
        } detail: {
            switch nav.selection {
            case .dictation: DictationPane()
            case .history: HistoryView()
            case .models: ModelsSettings()
            case .text: TextSettings()
            case .ai: AISettings()
            case .license: LicenseSettings()
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .navigationTitle("Desi Dictation")
    }
}
