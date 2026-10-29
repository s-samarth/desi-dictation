import Foundation
import Combine

public struct ModelDescriptor: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let sizeMB: Int

    public init(name: String, path: String, sizeMB: Int) {
        self.name = name
        self.path = path
        self.sizeMB = sizeMB
    }
    /// True for Hinglish fine-tunes (detected by filename convention).
    public var isHinglish: Bool { name.contains("hinglish") }
    /// True for Parakeet TDT files — a different runtime (EngineRouter) and
    /// English-only for us, so it must never be offered for हिन्दी/Hinglish.
    public var isParakeet: Bool { name.contains("parakeet") }
    /// True for Qwen3-ASR files (transcribe.cpp engine) — English-only here.
    public var isQwenASR: Bool { name.contains("qwen3-asr") }
}

public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()

    @Published public private(set) var installed: [ModelDescriptor] = []
    @Published public var downloadProgress: [String: Double] = [:]  // id -> 0…1
    @Published public var downloadErrors: [String: String] = [:]   // id -> message

    private init() { refresh() }

    public func isInstalled(_ model: DownloadableModel) -> Bool {
        FileManager.default.fileExists(
            atPath: AppPaths.modelsDirectory.appendingPathComponent("ggml-\(model.id).bin").path)
    }

    /// Installed models that actually serve this language, best first. The
    /// model pickers show only these: being asked to pick "English" and then
    /// hunt for a model that speaks English is the app doing its job badly
    /// (v0.6.1 feedback). Score 0 = wrong script or wrong language → hidden.
    public func candidates(for mode: LanguageMode) -> [ModelDescriptor] {
        installed
            .map { ($0, Self.score($0, for: mode)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    /// What "Auto" resolves to right now — shown inline in the picker so the
    /// default is never a mystery.
    public func autoChoice(for mode: LanguageMode) -> ModelDescriptor? {
        candidates(for: mode).first
    }

    /// Picks the best installed model for a mode. Empty `pinnedPath` = Auto.
    /// Scoring encodes: Hinglish fine-tunes win for Hinglish; stock multilingual
    /// wins for English/Hindi; quantized variants beat f32/f16 (faster, less RAM);
    /// Hinglish models are EXCLUDED for Hindi (they can only emit Roman script).
    public func resolveModel(for mode: LanguageMode, pinnedPath: String) -> ModelDescriptor? {
        if !pinnedPath.isEmpty, let pinned = installed.first(where: { $0.path == pinnedPath }) {
            return pinned
        }
        return installed
            .map { ($0, Self.score($0, for: mode)) }
            .filter { $0.1 > 0 }
            .max { $0.1 < $1.1 }?.0
    }

    /// Scans the Application Support models dir plus DESI_MODELS_DIR (dev override).
    public func refresh() {
        var dirs = [AppPaths.modelsDirectory]
        if let dev = ProcessInfo.processInfo.environment["DESI_MODELS_DIR"] {
            dirs.append(URL(fileURLWithPath: dev))
        }
        var found: [ModelDescriptor] = []
        for dir in dirs {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for file in files where file.pathExtension == "bin" {
                let name = file.deletingPathExtension().lastPathComponent
                // VAD and the context checker are helpers, not transcription models.
                guard !name.contains("silero"), !name.contains(ContextChecker.modelID) else { continue }
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                found.append(ModelDescriptor(
                    name: name, path: file.path, sizeMB: size / 1_048_576))
            }
        }
        installed = found.sorted { $0.sizeMB < $1.sizeMB }
    }

    /// Downloads a catalog model with progress; errors surface in
    /// `downloadErrors` (never silently — v0.3 bug: buttons "did nothing").
    public func download(_ model: DownloadableModel) async {
        await MainActor.run {
            downloadErrors[model.id] = nil
            downloadProgress[model.id] = 0
        }
        do {
            try await downloadVerified(model)
            await MainActor.run {
                downloadProgress[model.id] = nil
                refresh()
            }
        } catch {
            await MainActor.run {
                downloadProgress[model.id] = nil
                downloadErrors[model.id] = Self.friendlyMessage(for: error, model: model)
            }
        }
    }

    private func downloadVerified(_ model: DownloadableModel) async throws {
        let destination = AppPaths.modelsDirectory
            .appendingPathComponent("ggml-\(model.id).bin")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }

        guard !model.sha256.isEmpty else {
            throw NSError(domain: "ModelManager", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "This model's checksum isn't pinned yet, so it can't be verified."])
        }
        let tempURL = try await ModelDownloader(id: model.id, manager: self).run(url: model.url)
        // Integrity check: refuse tampered/truncated files (whisper.cpp parses
        // these in C — never feed it unverified bytes).
        let actual = try Self.sha256(of: tempURL)
        guard actual == model.sha256 else {
            try? FileManager.default.removeItem(at: tempURL)
            throw NSError(domain: "ModelManager", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Checksum mismatch — download discarded. Try again."])
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
    }

    private static func friendlyMessage(for error: Error, model: DownloadableModel) -> String {
        if model.url.absoluteString.hasPrefix(hinglishRepoBase),
           (error as NSError).code == NSError(domain: "ModelManager", code: 404).code
            || error.localizedDescription.contains("404") {
            return "Hinglish model repo isn't published yet (see scripts/publish_models.sh)."
        }
        return error.localizedDescription
    }
}
