import SwiftUI
import DesiDictationKit

/// Models page: which model each language uses, and the downloads list. One
/// list, not "installed" plus "downloads" — a row says whether you have it.
struct ModelsPane: View {
    @ObservedObject var models = ModelManager.shared
    @ObservedObject var license = LicenseManager.shared

    var body: some View {
        Form {
            DefaultModelSettings()

            Section {
                ForEach(ModelManager.catalog) { row($0) }
                HStack {
                    Text("Models folder").foregroundStyle(.secondary)
                    Spacer()
                    Button("Show in Finder") { NSWorkspace.shared.open(AppPaths.modelsDirectory) }
                    Button("Refresh") { models.refresh() }
                }
            } header: {
                Text("Downloads")
            } footer: {
                Text("⭐ = our pick for that language. Get the VAD add-on too.").footnote()
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ item: DownloadableModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text((item.recommended ? "⭐ " : "") + item.label
                     + (item.pro && LicenseManager.gatingEnabled ? "  (Pro)" : ""))
                Chip(text: item.category, color: Theme.color(forCategory: item.category))
                if let error = models.downloadErrors[item.id] {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
            Spacer()
            if models.isInstalled(item) {
                Label("Installed", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.caption)
            } else if let progress = models.downloadProgress[item.id] {
                ProgressView(value: progress).frame(width: 90)
            } else {
                Button("Get · \(item.approxMB) MB") {
                    Task { await models.download(item) }
                }
                .disabled(item.pro && !license.isPro)
            }
        }
    }
}
