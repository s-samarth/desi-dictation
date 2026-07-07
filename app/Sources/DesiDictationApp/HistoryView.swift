import SwiftUI
import DesiDictationKit

/// Rolling 24-hour dictation history: search, copy, clear. Local-only.
struct HistoryView: View {
    @ObservedObject var history = HistoryStore.shared
    @ObservedObject var settings = SettingsStore.shared
    @State private var query = ""

    private var filtered: [HistoryEntry] {
        guard !query.isEmpty else { return history.entries }
        return history.entries.filter {
            $0.text.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search dictations…", text: $query)
                    .textFieldStyle(.roundedBorder)
                Spacer()
                Toggle("Keep history", isOn: $settings.historyEnabled)
                    .toggleStyle(.switch)
            }
            .padding()

            if !settings.historyEnabled && history.entries.isEmpty {
                emptyState("History is off",
                           "Nothing is being saved. Flip the toggle to keep the last 24 hours.")
            } else if filtered.isEmpty {
                emptyState(query.isEmpty ? "No dictations yet" : "No matches",
                           query.isEmpty ? "Your last 24 hours of dictations will appear here."
                                         : "Try a different search.")
            } else {
                List(filtered) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.text)
                            .textSelection(.enabled)
                            .lineLimit(4)
                        HStack {
                            Text(entry.date, style: .relative) + Text(" ago")
                            Text(entry.mode)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                            Spacer()
                            Button("Copy") {
                                TextInserter.insert(entry.text, copyOnly: true)
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)
            }

            Divider()
            HStack {
                Text("\(history.entries.count) dictations in the last 24 h")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Clear All", role: .destructive) { history.clear() }
                    .disabled(history.entries.isEmpty)
            }
            .padding(10)
        }
    }

    private func emptyState(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle).foregroundStyle(.tertiary)
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
