import SwiftUI
import DesiDictationKit

/// First-launch setup (FIRST_RUN.md): one question per page, with Back and
/// Continue, instead of one long scroll (user review 2026-10-30: "cluttered,
/// cut off, no journey"). Models download in the background from the
/// Models page on, so the rest of setup never waits for them.
struct OnboardingView: View {
    static let size = NSSize(width: 680, height: 700)
    @StateObject private var flow: OnboardingModel
    @ObservedObject private var models = ModelManager.shared

    /// `start` lets UISnapshots draw any page.
    init(start: OnboardingModel.Step = .welcome) {
        let flow = OnboardingModel()
        flow.step = start
        _flow = StateObject(wrappedValue: flow)
    }

    var body: some View {
        VStack(spacing: 0) {
            if flow.step != .welcome {
                StepProgress(current: flow.step)
                    .padding(.horizontal, 32).padding(.top, 20)
            }
            ScrollView {
                page
                    .padding(.horizontal, 32).padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            footer.padding(.horizontal, 32).padding(.vertical, 16)
        }
        .tint(Theme.accent)
        .frame(width: Self.size.width, height: Self.size.height)
        .animation(.easeInOut(duration: 0.2), value: flow.step)
    }

    @ViewBuilder private var page: some View {
        switch flow.step {
        case .welcome: WelcomeStep()
        case .language: LanguageStep(flow: flow)
        case .models: ModelsStep(flow: flow)
        case .permissions: PermissionsStep()
        case .words: WordsStep(flow: flow)
        case .review: ReviewStep()
        case .done: DoneStep(flow: flow)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if flow.step != .welcome {
                Button("Back") { flow.back() }.controlSize(.large)
            }
            Spacer()
            if flow.step.rawValue > OnboardingModel.Step.models.rawValue {
                DownloadStatus(flow: flow)
            }
            primary
        }
    }

    @ViewBuilder private var primary: some View {
        switch flow.step {
        case .welcome:
            mainButton("Get started") { flow.next() }
        case .models:
            mainButton(flow.allDownloaded ? "Continue" : "Download \(flow.missingMB) MB and continue") {
                flow.startDownloads()
                flow.next()
            }
            .disabled(flow.wanted.count == 1)   // only the VAD: no English model picked
        case .done:
            mainButton("Finish and start dictating") { flow.finish() }
                .disabled(!flow.allDownloaded)
        default:
            mainButton("Continue") { flow.next() }
        }
    }

    private func mainButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
    }
}

/// Footer note while models download: progress, done, or a retry.
struct DownloadStatus: View {
    @ObservedObject var flow: OnboardingModel
    @ObservedObject private var models = ModelManager.shared

    var body: some View {
        if flow.allDownloaded {
            Label("Models ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green).font(.callout)
        } else if flow.failed {
            Button("Download failed. Retry") { flow.startDownloads() }
                .buttonStyle(.link).foregroundStyle(.red)
        } else {
            HStack(spacing: 8) {
                ProgressView(value: flow.progress).frame(width: 90)
                Text("Downloading models… \(Int(flow.progress * 100))%")
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}
