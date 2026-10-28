import SwiftUI
import DesiDictationKit

/// Shown only once paid tiers exist (LicenseManager.gatingEnabled).
struct LicenseSettings: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var license = LicenseManager.shared

    var body: some View {
        Form {
            if !LicenseManager.gatingEnabled {
                Label("Beta: everything is free — all models, all features.",
                      systemImage: "gift.fill")
                    .foregroundStyle(.green)
                Text("A paid Pro tier may arrive later; whatever you use during the beta stays yours.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                TextField("Gumroad license key", text: $settings.licenseKey)
                Button("Activate") {
                    Task { await license.activate(key: settings.licenseKey) }
                }
                if let error = license.lastError {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .formStyle(.grouped)
    }
}
