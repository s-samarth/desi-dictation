import Foundation
import DesiDictationKit

/// Send Feedback (FEEDBACK.md): only what the window shows is sent.
func runFeedbackTests() {
    T.begin("Feedback — the body holds only what the user filled in")
    func fields(_ report: FeedbackReport) -> [String: String] {
        (try? JSONSerialization.jsonObject(with: report.body())) as? [String: String] ?? [:]
    }
    T.equal(fields(FeedbackReport(message: "  Paste went nowhere  ")), ["message": "Paste went nowhere"],
            "message alone, trimmed; no IDs or settings added")
    let full = FeedbackReport(message: "hi", replyTo: "a@b.co", appInfo: "Desi Dictation 0.7.0", lastDictation: "meet at 3")
    T.equal(Set(fields(full).keys), ["message", "replyTo", "appInfo", "lastDictation"], "ticked parts included")
    T.equal(fields(FeedbackReport(message: "hi", replyTo: " ", appInfo: nil, lastDictation: "")).keys.count, 1,
            "unticked or empty parts left out")
    T.equal(fields(FeedbackReport(message: "hi", lastDictation: String(repeating: "x", count: 4000)))["lastDictation"]?.count,
            3000, "cut to the endpoint's limit")

    T.begin("Feedback — Send waits for something sendable")
    T.expect(FeedbackReport(message: " ").problem != nil, "an empty message can't be sent")
    T.expect(FeedbackReport(message: "hi", replyTo: "nope").problem != nil, "a bad reply address is caught")
    T.expect(FeedbackReport(message: "hi", replyTo: "").problem == nil, "no reply address is fine")

    T.begin("Feedback — what the reply means")
    T.equal(FeedbackSender.outcome(status: 200), .sent, "200 = sent")
    T.expect(FeedbackSender.outcome(status: 429) != .sent, "429 = try later")
    T.expect(FeedbackSender.outcome(status: 502) != .sent, "a mail-service failure says so")
}
