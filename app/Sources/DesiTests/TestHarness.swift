import Foundation

/// Micro test harness — the CLT toolchain ships no XCTest, so tests are a
/// plain executable: `swift run desi-tests`, exit 0 = green (used by CI-ish
/// scripts and the pre-release checklist).
enum T {
    static var failures = 0
    static var passes = 0
    private static var section = ""

    static func begin(_ name: String) {
        section = name
        print("\n── \(name)")
    }

    static func expect(_ condition: Bool, _ name: String,
                       _ detail: @autoclosure () -> String = "", line: Int = #line) {
        if condition {
            passes += 1
            print("  ✓ \(name)")
        } else {
            failures += 1
            let extra = detail()
            print("  ✗ \(name)\(extra.isEmpty ? "" : " — \(extra)") [\(section):\(line)]")
        }
    }

    static func equal<E: Equatable>(_ actual: E, _ expected: E, _ name: String, line: Int = #line) {
        expect(actual == expected, name, "got \(actual), want \(expected)", line: line)
    }

    static func finish() -> Never {
        print("\n\(passes) passed, \(failures) failed")
        exit(failures == 0 ? 0 : 1)
    }

    /// Fresh temp file path for stores under test (never the real app support).
    static func tempFile(_ name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("desi-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
