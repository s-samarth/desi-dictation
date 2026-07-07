import Foundation
import Combine

/// Gumroad license verification (Phase 4 of plan.md).
///
/// Free tier: Hinglish Swift + Whisper Base models, core dictation.
/// Pro: larger models, Ollama AI cleanup. Verification result is cached in
/// UserDefaults so the app works offline after first activation.
///
/// NOTE (pre-launch): `productID` is empty until the Gumroad product exists, so
/// `isPro` falls back to the dev unlock flag:
///   defaults write com.desi.dictation devUnlock -bool true
public final class LicenseManager: ObservableObject {
    public static let shared = LicenseManager()

    /// Set to the Gumroad product ID at launch time (docs/LAUNCH.md step 4).
    public static let productID = ""

    /// BETA: everything is free — no Pro tier yet. Flip to true at Gumroad
    /// launch to re-enable gating (all the plumbing below stays intact).
    public static let gatingEnabled = false

    @Published public private(set) var isActivated: Bool
    @Published public private(set) var lastError: String?

    private let defaults = UserDefaults.standard

    private init() {
        isActivated = defaults.bool(forKey: "licenseActivated")
    }

    public var isPro: Bool {
        guard Self.gatingEnabled else { return true }   // free-for-all beta
        return isActivated || defaults.bool(forKey: "devUnlock")
    }

    public func activate(key: String) async {
        guard !Self.productID.isEmpty else {
            await set(error: "Licensing not configured yet (pre-launch build). "
                + "Use the dev unlock: defaults write com.desi.dictation devUnlock -bool true")
            return
        }
        guard let url = URL(string: "https://api.gumroad.com/v2/licenses/verify") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = "product_id=\(Self.productID)"
            + "&license_key=\(key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key)"
            + "&increment_uses_count=true"
        request.httpBody = body.data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let success = json?["success"] as? Bool ?? false
            let refunded = (json?["purchase"] as? [String: Any])?["refunded"] as? Bool ?? false

            if success && !refunded {
                await MainActor.run {
                    self.isActivated = true
                    self.lastError = nil
                    self.defaults.set(true, forKey: "licenseActivated")
                }
            } else {
                await set(error: "License key not valid (or refunded).")
            }
        } catch {
            await set(error: "Could not reach Gumroad: \(error.localizedDescription)")
        }
    }

    public func deactivate() {
        isActivated = false
        defaults.set(false, forKey: "licenseActivated")
    }

    @MainActor private func set(error: String) {
        lastError = error
    }
}
