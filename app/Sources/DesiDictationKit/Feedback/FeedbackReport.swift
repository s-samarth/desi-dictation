import Foundation

/// One report from the Send Feedback window (FEEDBACK.md). It holds exactly
/// what the window shows; `body()` is the whole of what leaves the Mac, and
/// only when the user presses Send. No IDs, no audio, no settings beyond the
/// app-info line the user can see and untick.
public struct FeedbackReport: Equatable, Sendable {
    public var message: String
    public var replyTo: String
    /// nil = not included.
    public var appInfo: String?
    /// nil = not included (the default).
    public var lastDictation: String?

    /// The endpoint's limits (samarthsaraswat.com api/feedback.ts).
    public static let limits = (message: 5000, replyTo: 200, appInfo: 500, lastDictation: 3000)

    public init(message: String = "", replyTo: String = "", appInfo: String? = nil, lastDictation: String? = nil) {
        self.message = message
        self.replyTo = replyTo
        self.appInfo = appInfo
        self.lastDictation = lastDictation
    }

    private static func trimmed(_ s: String?) -> String {
        (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Why Send is unavailable, or nil when the report can go.
    public var problem: String? {
        let message = Self.trimmed(message), reply = Self.trimmed(replyTo)
        if message.isEmpty { return "Write a line about what happened." }
        if message.count > Self.limits.message { return "That's a bit long: keep it under 5,000 characters." }
        if !reply.isEmpty, reply.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            return "The reply address doesn't look like an email."
        }
        return nil
    }

    /// The JSON sent: the message, plus only the parts that are filled in,
    /// each cut to the endpoint's limit.
    public func body() -> Data {
        var fields: [String: String] = ["message": String(Self.trimmed(message).prefix(Self.limits.message))]
        let optional: [(String, String?, Int)] = [
            ("replyTo", replyTo, Self.limits.replyTo),
            ("appInfo", appInfo, Self.limits.appInfo),
            ("lastDictation", lastDictation, Self.limits.lastDictation),
        ]
        for (key, value, limit) in optional where !Self.trimmed(value).isEmpty {
            fields[key] = String(Self.trimmed(value).prefix(limit))
        }
        return (try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])) ?? Data()
    }

    /// "Desi Dictation 0.7.0 · macOS 15.1 · english · model: auto": shown in
    /// the window as it will be sent.
    public static func appInfo(version: String, os: String, language: String, model: String) -> String {
        "Desi Dictation \(version) · macOS \(os) · \(language) · model: \(model)"
    }
}

/// Sends a report to the site, which forwards it to Samarth's inbox.
public enum FeedbackSender {
    public static let endpoint = URL(string: "https://www.samarthsaraswat.com/api/feedback")!

    public enum Outcome: Equatable, Sendable {
        case sent
        case failed(String)
    }

    public static func send(_ report: FeedbackReport) async -> Outcome {
        var request = URLRequest(url: endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("feedback-1", forHTTPHeaderField: "X-Desi-Dictation")
        request.httpBody = report.body()
        // Ephemeral: no cookies, no cache, nothing kept from the exchange.
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return outcome(status: status)
        } catch {
            return .failed("Couldn't reach the internet. Copy it, or email instead.")
        }
    }

    /// What a reply status means for the user.
    public static func outcome(status: Int) -> Outcome {
        switch status {
        case 200: return .sent
        case 429: return .failed("Too many reports just now. Try again in a few minutes.")
        default: return .failed("Couldn't send it right now. Copy it, or email instead.")
        }
    }
}
