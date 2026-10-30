import SwiftUI
import DesiDictationKit

/// The app's one window (menu bar → Open Desi Dictation…). Five pages, always reachable
/// from the sidebar. Unreleased features stay out of the list entirely rather
/// than showing up as a dead page.
enum SidebarItem: String, CaseIterable, Identifiable {
    case guide, dictation, vocabulary, history, models, ai, license
    var id: String { rawValue }

    /// What the sidebar shows today.
    static var visible: [SidebarItem] {
        allCases.filter { item in
            switch item {
            case .ai: return SettingsStore.aiFeaturesReleased
            case .license: return LicenseManager.gatingEnabled
            default: return true
            }
        }
    }

    var title: String {
        switch self {
        case .guide: return "Guide"
        case .dictation: return "Dictation"
        case .vocabulary: return "Vocabulary"
        case .history: return "History"
        case .models: return "Models"
        case .ai: return "AI"
        case .license: return "License"
        }
    }

    var icon: String {
        switch self {
        case .guide: return "lightbulb"
        case .dictation: return "mic"
        case .vocabulary: return "text.book.closed"
        case .history: return "clock.arrow.circlepath"
        case .models: return "cpu"
        case .ai: return "sparkles"
        case .license: return "key"
        }
    }
}

/// Sidebar selection, reachable from outside the view hierarchy (menu items
/// deep-link straight to a page).
@MainActor
final class MainNav: ObservableObject {
    static let shared = MainNav()
    /// The Guide opens first until it has been seen once.
    @Published var selection: SidebarItem =
        UserDefaults.standard.bool(forKey: MainNav.guideSeenKey) ? .dictation : .guide
    static let guideSeenKey = "guideSeen"
}

struct MainWindow: View {
    static let size = NSSize(width: 720, height: 540)
    @ObservedObject private var nav = MainNav.shared

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.visible, selection: Binding(
                get: { Optional(nav.selection) },
                set: { nav.selection = $0 ?? .guide })) { item in
                Label { Text(item.title) } icon: { IconTile(symbol: item.icon, color: item.tint) }
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 170, max: 200)
        } detail: {
            // Every page is a grouped Form: it scrolls inside the window. A
            // plain Form doesn't, so a long page outgrew the window and hid
            // the sidebar — no way back (BUILD_LOG FM#35).
            VStack(spacing: 0) {
                UpdateBanner()
                Group {
                    switch nav.selection {
                    case .guide: GuidePane()
                    case .dictation: DictationPane()
                    case .vocabulary: VocabularyPane()
                    case .history: HistoryView()
                    case .models: ModelsPane()
                    case .ai: AISettings()
                    case .license: LicenseSettings()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .tint(Theme.accent)
        .frame(minWidth: 640, minHeight: 440)
        .navigationTitle(nav.selection.title)
    }
}

extension LanguageMode {
    /// Languages the pickers offer: AI-only modes stay hidden while AI is off.
    @MainActor static var offered: [LanguageMode] {
        allCases.filter { SettingsStore.shared.aiFeaturesEnabled || !$0.needsLLM }
    }
}

extension Text {
    /// Section footer, aligned with the rows above it (grouped forms
    /// right-align footers by default, which reads as a stray caption).
    func footnote() -> some View {
        font(.callout).foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 10)
    }
}

extension ModelDescriptor {
    /// "Qwen (most accurate)" rather than "ggml-qwen3-asr-1.7b-q8_0": the
    /// catalog's short name for a downloaded file, else the file name.
    var displayName: String {
        guard let entry = ModelManager.catalog.first(where: { "ggml-\($0.id)" == name }) else {
            return name
        }
        return ModelManager.shortName(for: entry.id) ?? entry.label.components(separatedBy: " — ").first ?? entry.label
    }
}
