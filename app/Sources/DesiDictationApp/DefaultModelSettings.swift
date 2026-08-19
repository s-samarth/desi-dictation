import SwiftUI
import DesiDictationKit

/// "Default model for each language" — Settings → Models.
///
/// The rule this encodes (v0.6.1 feedback): choosing a *language* is the user's
/// job; choosing the *model* that serves it is ours. Each language keeps its own
/// default, switching language switches model silently, and a language never
/// lists models that can't produce its script — a Hinglish model can't write
/// Devanagari and Parakeet can't write Hindi at all, so neither is offered
/// there (ModelManager.score).
struct DefaultModelSettings: View {
    @ObservedObject private var settings = SettingsStore.shared
    @ObservedObject private var models = ModelManager.shared

    /// anyToEnglish shares Hinglish's model (it transcribes, then translates),
    /// so it isn't a separate row.
    private let languages: [LanguageMode] = [.hinglish, .english, .hindi]

    var body: some View {
        Section {
            ForEach(languages, id: \.self) { mode in
                Picker(mode.displayName, selection: binding(for: mode)) {
                    Text(autoLabel(for: mode)).tag("")
                    ForEach(models.candidates(for: mode)) { model in
                        Text("\(model.name) (\(model.sizeMB) MB)").tag(model.path)
                    }
                }
            }
        } header: {
            Text("Default model per language")
        } footer: {
            Text("Pick a language in the menu bar and the right model loads itself. "
                 + "Auto follows our recommendation as you install better models; "
                 + "pin one here if you prefer a specific file.")
                .font(.caption)
        }
    }

    private func binding(for mode: LanguageMode) -> Binding<String> {
        Binding(
            get: { settings.modelPath(for: mode) },
            set: { path in
                settings.setModelPath(path, for: mode)
                // Applies immediately when it's the language in use.
                DictationController.shared.modelChanged()
            })
    }

    private func autoLabel(for mode: LanguageMode) -> String {
        guard let pick = models.autoChoice(for: mode) else {
            return "Auto — none installed yet"
        }
        return "Auto (\(pick.name))"
    }
}
