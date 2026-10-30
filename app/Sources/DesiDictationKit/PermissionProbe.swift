import ApplicationServices
import CoreGraphics
import Foundation

/// Asks macOS afresh whether Accessibility and Input Monitoring are on.
///
/// `AXIsProcessTrusted` keeps its first answer for the life of the process
/// (macOS 27, BUILD_LOG FM#44): turn Accessibility on in System Settings and
/// a running app still reads "no", and `CGPreflightListenEventAccess` lags
/// the same way. A short-lived copy of this app asks instead. macOS judges a
/// child process as the app that started it, so its answer is this app's.
public enum PermissionProbe {
    static let flag = "--permission-probe"
    /// Exit codes: base + 1 for Accessibility, + 2 for Input Monitoring. A
    /// base well above 0 and 1 so a crash or a plain exit can't pass as one.
    static let base: Int32 = 40

    /// Call first thing at launch. In the probe copy it answers and exits;
    /// in the real app it returns at once.
    public static func answerIfAsked() {
        guard CommandLine.arguments.contains(flag) else { return }
        exit(base + (AXIsProcessTrusted() ? 1 : 0) + (CGPreflightListenEventAccess() ? 2 : 0))
    }

    /// Runs the probe copy and reads its answer. Blocks for ~0.1 s, so call
    /// it off the main thread. Nil when there's no app bundle to run (tests,
    /// a bare binary) or the probe didn't answer.
    public static func ask() -> (accessibility: Bool, inputMonitoring: Bool)? {
        guard let executable = Bundle.main.executableURL else { return nil }
        let probe = Process()
        probe.executableURL = executable
        probe.arguments = [flag]
        probe.standardOutput = FileHandle.nullDevice
        probe.standardError = FileHandle.nullDevice
        guard (try? probe.run()) != nil else { return nil }
        probe.waitUntilExit()
        let answer = probe.terminationStatus - base
        guard probe.terminationReason == .exit, (0...3).contains(answer) else { return nil }
        return (answer & 1 != 0, answer & 2 != 0)
    }
}
