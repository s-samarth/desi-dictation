import SwiftUI
import DesiDictationKit

/// The main app window (MacWhisper-style sidebar layout). The menu bar icon is
/// for quick toggles; this window is where users actually configure things —
/// added after v0.1 feedback that a bare menu bar icon felt undiscoverable.
enum SidebarItem: String, CaseIterable, Identifiable {
    case dictation, history, models, text, license
    var id: String { rawValue }

    var title: String {
        switch self {
        case .dictation: return "Dictation"
        case .history: return "History"
        case .models: return "Models"
        case .text: return "Text & AI"
        case .license: return "License"
        }
    }

    var icon: String {
        switch self {
        case .dictation: return "mic"
        case .history: return "clock.arrow.circlepath"
        case .models: return "cpu"
        case .text: return "character.cursor.ibeam"
        case .license: return "key"
        }
    }
}

struct MainWindow: View {
    @State private var selection: SidebarItem = .dictation

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 180)
        } detail: {
            switch selection {
            case .dictation: DictationPane()
            case .history: HistoryView()
            case .models: ModelsSettings()
            case .text: TextSettings()
            case .license: LicenseSettings()
            }
        }
        .frame(minWidth: 680, minHeight: 460)
        .navigationTitle("Desi Dictation")
    }
}
