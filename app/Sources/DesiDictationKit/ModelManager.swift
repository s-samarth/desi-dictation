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
}

public final class ModelManager: ObservableObject {
    public static let shared = ModelManager()

    @Published public private(set) var installed: [ModelDescriptor] = []
    @Published public var downloadProgress: [String: Double] = [:]  // id -> 0…1

    public static let catalog: [DownloadableModel] = [
        .init(id: "base", label: "Whisper Base (Hindi/English, fast)",
              url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin")!,
              approxMB: 148, pro: false),
        .init(id: "small", label: "Whisper Small (better Hindi)",
              url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin")!,
              approxMB: 488, pro: true),
        .init(id: "large-v3-turbo-q5_0", label: "Whisper Large v3 Turbo q5 (best stock)",
              url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!,
              approxMB: 574, pro: true),
    ]

    private init() { refresh() }

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
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                found.append(ModelDescriptor(
                    name: file.deletingPathExtension().lastPathComponent,
                    path: file.path,
                    sizeMB: size / 1_048_576))
            }
        }
        installed = found.sorted { $0.sizeMB < $1.sizeMB }
    }

    /// Downloads a catalog model into the models dir, publishing progress.
    public func download(_ model: DownloadableModel) async throws {
        let destination = AppPaths.modelsDirectory
            .appendingPathComponent("ggml-\(model.id).bin")
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }

        let (tempURL, response) = try await URLSession.shared.download(
            from: model.url, delegate: ProgressDelegate(id: model.id, manager: self))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        await MainActor.run {
            downloadProgress[model.id] = nil
            refresh()
        }
    }

    private final class ProgressDelegate: NSObject, URLSessionTaskDelegate {
        let id: String
        weak var manager: ModelManager?
        init(id: String, manager: ModelManager) { self.id = id; self.manager = manager }

        func urlSession(_ session: URLSession, task: URLSessionTask,
                        didSendBodyData bytesSent: Int64,
                        totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {}

        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                        didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                        totalBytesExpectedToWrite: Int64) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async { [weak manager, id] in
                manager?.downloadProgress[id] = fraction
            }
        }
    }
}
