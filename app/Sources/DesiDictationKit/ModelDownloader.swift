import CryptoKit
import Foundation

extension ModelManager {
    /// Streaming SHA256 (files are 100–600 MB; never load them whole into RAM).
    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 * 1_048_576), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// Classic delegate-based download wrapped for async/await. The modern
/// `URLSession.download(from:delegate:)` never invoked our progress
/// callback (wrong protocol conformance) — this path is fully documented:
/// didWriteData → progress; didFinishDownloadingTo → move file NOW (it's
/// deleted after the callback returns); didComplete → error handling.
final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
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
