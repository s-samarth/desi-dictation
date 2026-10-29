import AppKit
import SwiftUI
import DesiDictationKit

/// Send Feedback (FEEDBACK.md): everything that would be sent is on screen,
/// the optional parts are tick boxes, and nothing leaves the Mac until Send.
/// "Email instead" keeps the old mail draft; "Copy" works offline.
struct FeedbackView: View {
    @State private var message = ""
    @State private var replyTo = ""
    @State private var includeInfo = true
    @State private var includeDictation: Bool
    @State private var sending = false
    @State private var status: FeedbackSender.Outcome?
    private let info: String
    private let dictation: String

    init(includeLastDictation: Bool = false) {
        _includeDictation = State(initialValue: includeLastDictation)
        dictation = DictationController.shared.lastTranscript
        let settings = SettingsStore.shared
        let pinned = settings.modelPath(for: settings.languageMode)
        info = FeedbackReport.appInfo(
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev",
            os: { let v = ProcessInfo.processInfo.operatingSystemVersion
                  return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" }(),
            language: settings.languageMode.rawValue,
            model: pinned.isEmpty ? "auto" : (pinned as NSString).lastPathComponent)
    }

    private var report: FeedbackReport {
        FeedbackReport(message: message, replyTo: replyTo,
                       appInfo: includeInfo ? info : nil,
                       lastDictation: includeDictation && !dictation.isEmpty ? dictation : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What happened, or what would you change?").font(.headline)
            TextEditor(text: $message)
                .font(.body)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.neutral.opacity(0.3)))
            TextField("Your email, if you'd like a reply (optional)", text: $replyTo)
                .textFieldStyle(.roundedBorder)
            Toggle("Include app info", isOn: $includeInfo)
            if includeInfo { shown(info) }
            Toggle("Include my last dictation", isOn: $includeDictation).disabled(dictation.isEmpty)
            if includeDictation, !dictation.isEmpty { shown(dictation) }
            Text("Sent to samarthsaraswat.com only when you press Send, forwarded to Samarth's inbox, and not stored. Nothing else goes: no audio, no IDs.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            footer
        }
        .padding(18)
        .frame(width: 520)
        .tint(Theme.accent)
    }

    /// Text that would be sent, shown as it will go.
    private func shown(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.neutral.opacity(0.08)))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            statusText
            Spacer()
            Button("Email instead") { Feedback.compose(includeLastTranscript: includeDictation) }
            Button("Copy") {
                let r = report
                TextInserter.copy([r.message, r.appInfo, r.lastDictation].compactMap { $0 }.joined(separator: "\n\n"))
            }
            Button(sending ? "Sending…" : "Send") { send() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(sending || report.problem != nil || status == .sent)
        }
    }

    @ViewBuilder private var statusText: some View {
        switch status {
        case .sent: Text("Sent. Thank you!").font(.caption).foregroundStyle(Theme.hindi)
        case .failed(let why): Text(why).font(.caption).foregroundStyle(.orange)
        case nil:
            if let problem = report.problem, !message.isEmpty {
                Text(problem).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func send() {
        sending = true
        status = nil
        let r = report
        Task { @MainActor in
            status = await FeedbackSender.send(r)
            sending = false
        }
    }
}
