import Foundation
#if DESI_LLAMA
import CLlamaScore
#endif

/// `ContextScorer` over llama.cpp (native/desi_lm). Compiled in only when
/// Package.swift found app/Libraries/libllama-bundle.a (setup_llama.sh).
public final class LlamaContextScorer: ContextScorer {
    /// The runtime is in this build. False on CI and before setup_llama.sh.
    public static var isAvailable: Bool {
        #if DESI_LLAMA
        return true
        #else
        return false
        #endif
    }

    private let lock = NSLock()
    #if DESI_LLAMA
    private let handle: OpaquePointer
    #endif

    /// nil when the runtime is missing or the file isn't a loadable model.
    public init?(modelPath: String, gpuLayers: Int32 = 99) {
        #if DESI_LLAMA
        guard let handle = desi_lm_load(modelPath, 512, gpuLayers) else { return nil }
        self.handle = handle
        #else
        return nil
        #endif
    }

    deinit {
        #if DESI_LLAMA
        desi_lm_free(handle)
        #endif
    }

    public func logProbability(of text: String, after prefix: String) -> Double? {
        #if DESI_LLAMA
        lock.lock(); defer { lock.unlock() }
        var logprob = 0.0
        var tokens: Int32 = 0
        guard desi_lm_score(handle, prefix, text, &logprob, &tokens) == 0 else { return nil }
        return logprob
        #else
        return nil
        #endif
    }

    public func tokenLogProbabilities(of text: String, after prefix: String) -> [(end: Int, logprob: Double)]? {
        #if DESI_LLAMA
        lock.lock(); defer { lock.unlock() }
        let capacity = 512
        var logprobs = [Double](repeating: 0, count: capacity)
        var ends = [Int32](repeating: 0, count: capacity)
        var count: Int32 = 0
        guard desi_lm_token_scores(handle, prefix, text, &logprobs, &ends, Int32(capacity), &count) == 0
        else { return nil }
        return (0..<Int(count)).map { (Int(ends[$0]), logprobs[$0]) }
        #else
        return nil
        #endif
    }
}

/// The app's one context checker: the model file, loading it off the main
/// thread, and keeping it warm (~0.4 GB RAM) while "when it fits" words exist.
public final class ContextChecker: @unchecked Sendable {
    public static let shared = ContextChecker()
    /// Catalog id; the file is models/ggml-<id>.bin like every other model.
    public static let modelID = "context-qwen3-0.6b-base-q4_k_m"

    public static var modelURL: URL {
        AppPaths.modelsDirectory.appendingPathComponent("ggml-\(modelID).bin")
    }

    /// "Only when it fits" can be offered: runtime built in and model downloaded.
    public static var isReady: Bool {
        LlamaContextScorer.isAvailable && FileManager.default.fileExists(atPath: modelURL.path)
    }

    private let lock = NSLock()
    private var scorer: LlamaContextScorer?
    private var failed = false
    private let queue = DispatchQueue(label: "desi.context.load", qos: .userInitiated)

    /// Key-down: start loading so the first dictation doesn't wait for it.
    public func warmUp() {
        guard Self.isReady else { return }
        queue.async { [self] in _ = loaded() }
    }

    /// The loaded scorer, loading it now if needed; nil if it can't load.
    public func loaded() -> ContextScorer? {
        lock.lock(); defer { lock.unlock() }
        if let scorer { return scorer }
        guard Self.isReady, !failed else { return nil }
        scorer = LlamaContextScorer(modelPath: Self.modelURL.path)
        failed = scorer == nil
        return scorer
    }

    /// Model deleted or replaced: forget the old one.
    public func reset() {
        lock.lock(); defer { lock.unlock() }
        scorer = nil
        failed = false
    }

    /// Before exit: let a `warmUp()` load finish, even one still queued, then
    /// free the model. A load still running at exit reads llama's unicode
    /// tables while exit tears them down (FM#42); a model still loaded aborts
    /// in Metal teardown (FM#27, FM#40).
    public func shutdown() {
        queue.sync {}
        reset()
    }
}
