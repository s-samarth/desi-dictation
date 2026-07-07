import CryptoKit
import Foundation
import Combine

public struct ModelDescriptor: Identifiable, Equatable {
    public var id: String { path }
    public let name: String
    public let path: String
    public let sizeMB: Int
    /// True for Hinglish fine-tunes (detected by filename convention).
    public var isHinglish: Bool { name.contains("hinglish") }
}

/// Stock multilingual GGML models downloadable straight from Hugging Face
/// (prebuilt by the whisper.cpp project). Hinglish models are produced locally
/// by scripts/convert_model.sh (or downloaded from our own HF repo post-launch).
public struct DownloadableModel: Identifiable {
    public let id: String
    public let label: String
    public let url: URL
    public let approxMB: Int
    public let pro: Bool
    /// Shown with a ⭐ in-app: our opinionated pick per category.
    public let recommended: Bool
    /// Which need it serves — rendered as a section hint in the Models UI.
    public let category: String
    /// SHA256 of the file — verified after download so a hijacked model repo
    /// can't feed us a tampered binary (whisper.cpp parses these files in C).
    public let sha256: String
}

public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()

    @Published public private(set) var installed: [ModelDescriptor] = []
    @Published public var downloadProgress: [String: Double] = [:]  // id -> 0…1
    @Published public var downloadErrors: [String: String] = [:]   // id -> message

    /// Base URL for our published Hinglish models — see scripts/publish_models.sh
    /// and docs/LAUNCH.md step 3. Overridable for forks/testing.
    public static let hinglishRepoBase = UserDefaults.standard.string(forKey: "modelRepoBase")
        ?? "https://huggingface.co/samarthsaraswat/desi-dictation-models/resolve/main"

    public static let catalog: [DownloadableModel] = [
        .init(id: "hinglish-apex-q5_0", label: "Hinglish Apex — best Hinglish accuracy",
              url: URL(string: "\(hinglishRepoBase)/ggml-hinglish-apex-q5_0.bin")!,
              approxMB: 547, pro: true, recommended: true, category: "Hinglish",
              sha256: "9d877151b15cec1feb9110cfbc0a3162cf377bcc0ab1935174226f461cf60f13"),
        .init(id: "hinglish-swift", label: "Hinglish Swift — light & fast",
              url: URL(string: "\(hinglishRepoBase)/ggml-hinglish-swift.bin")!,
              approxMB: 141, pro: false, recommended: false, category: "Hinglish",
              sha256: "4e9caa5f4b0416824d7cbeec22a37ef78a05e4b0189864eed65cd56d81c6b0a8"),
        .init(id: "large-v3-turbo-q5_0", label: "Whisper Large v3 Turbo — best English & हिन्दी",
              url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!,
              approxMB: 574, pro: true, recommended: true, category: "English / हिन्दी",
              sha256: "394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2"),
        .init(id: "base", label: "Whisper Base — light English/Hindi",
              url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
              approxMB: 148, pro: false, recommended: false, category: "English / हिन्दी",
              sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"),
        .init(id: "silero-vad", label: "Silero VAD — handles pauses & long dictations",
              url: URL(string: "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin")!,
              approxMB: 1, pro: false, recommended: true, category: "Engine add-on",
              sha256: "29940d98d42b91fbd05ce489f3ecf7c72f0a42f027e4875919a28fb4c04ea2cf"),
    ]

    private init() { refresh() }

    public func isInstalled(_ model: DownloadableModel) -> Bool {
        FileManager.default.fileExists(
            atPath: AppPaths.modelsDirectory.appendingPathComponent("ggml-\(model.id).bin").path)
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

    private static func score(_ model: ModelDescriptor, for mode: LanguageMode) -> Int {
        let name = model.name.lowercased()
        var score = 0
        switch mode {
        case .hinglish:
            if name.contains("hinglish-apex") { score = 100 }
            else if name.contains("hinglish-prime") { score = 90 }
            else if name.contains("hinglish-swift") { score = 50 }
            else if name.contains("turbo") { score = 40 }
            else if name.contains("small") { score = 30 }
            else if name.contains("base") { score = 20 }
        case .english:
            if name.contains("turbo") { score = 100 }
            else if name.contains("hinglish-apex") { score = 80 }   // great Indian English
            else if name.contains("small") { score = 60 }
            else if name.contains("hinglish-prime") { score = 55 }
            else if name.contains("base") { score = 40 }
            else if name.contains("hinglish-swift") { score = 30 }
        case .hindi:
            guard !model.isHinglish else { return 0 }               // wrong output script
            if name.contains("turbo") { score = 100 }
            else if name.contains("small") { score = 80 }
            else if name.contains("base") { score = 60 }
        }
        if score > 0, name.contains("q5") { score += 5 }            // prefer quantized
        return score
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
                // VAD model is an engine helper, not a transcription model.
                guard !name.contains("silero") else { continue }
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

        let tempURL = try await Downloader(id: model.id, manager: self).run(url: model.url)
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

    /// Streaming SHA256 (files are 100–600 MB; never load them whole into RAM).
    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 * 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Classic delegate-based download wrapped for async/await. The modern
    /// `URLSession.download(from:delegate:)` never invoked our progress
    /// callback (wrong protocol conformance) — this path is fully documented:
    /// didWriteData → progress; didFinishDownloadingTo → move file NOW (it's
    /// deleted after the callback returns); didComplete → error handling.
    private final class Downloader: NSObject, URLSessionDownloadDelegate {
        private let id: String
        private weak var manager: ModelManager?
        private var continuation: CheckedContinuation<URL, Error>?
        private var movedTo: URL?

        init(id: String, manager: ModelManager) { self.id = id; self.manager = manager }

        func run(url: URL) async throws -> URL {
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            defer { session.finishTasksAndInvalidate() }
            return try await withCheckedThrowingContinuation { cont in
                continuation = cont
                session.downloadTask(with: url).resume()
            }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                        totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async { [weak manager, id] in
                manager?.downloadProgress[id] = fraction
            }
        }

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didFinishDownloadingTo location: URL) {
            let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return }  // error surfaced in didComplete
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent("desi-\(UUID().uuidString).bin")
            try? FileManager.default.moveItem(at: location, to: temp)
            movedTo = temp
        }

        func urlSession(_ session: URLSession, task: URLSessionTask,
                        didCompleteWithError error: Error?) {
            let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
            if let error {
                continuation?.resume(throwing: error)
            } else if status != 200 {
                continuation?.resume(throwing: NSError(domain: "ModelManager", code: status,
                    userInfo: [NSLocalizedDescriptionKey: "Server returned \(status)."]))
            } else if let movedTo {
                continuation?.resume(returning: movedTo)
            } else {
                continuation?.resume(throwing: URLError(.cannotWriteToFile))
            }
            continuation = nil
        }
    }
}
