// swift-tools-version: 6.2
// NOTE: tools-version must track the installed CLT closely — the CLT ManifestAPI
// cannot link older manifest ABIs (docs/BUILD_LOG.md failure mode #3; recurred
// with CLT 6.3.3, which dropped the 6.0-era Package.init overload — bumped
// 6.0 → 6.2 on 2026-07-10). Language mode stays v5.
// Desi Dictation — SwiftPM package (no Xcode project; built with CLT only).
// whisper.cpp is linked as prebuilt static libs staged by scripts/setup_whisper.sh
// into ./Libraries and ./Sources/CWhisper/include.
import PackageDescription

let whisperLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(Context.packageDirectory)/Libraries"]),
    .linkedLibrary("whisper"),
    // Parakeet TDT runtime (English mode) — own static lib, shared ggml.
    .linkedLibrary("parakeet"),
    .linkedLibrary("ggml"),
    .linkedLibrary("ggml-base"),
    .linkedLibrary("ggml-cpu"),
    .linkedLibrary("ggml-blas"),
    .linkedLibrary("ggml-metal"),
    .linkedLibrary("c++"),
    .linkedFramework("Accelerate"),
    .linkedFramework("Metal"),
    .linkedFramework("MetalKit"),
    .linkedFramework("Foundation"),
]

let package = Package(
    name: "DesiDictation",
    platforms: [.macOS(.v14)],
    targets: [
        // C shim exposing whisper.h to Swift
        .systemLibrary(name: "CWhisper", path: "Sources/CWhisper"),

        // Core logic: audio, engine, hotkeys, insertion, settings, licensing
        .target(
            name: "DesiDictationKit",
            dependencies: ["CWhisper"],
            path: "Sources/DesiDictationKit",
            swiftSettings: [.unsafeFlags(["-swift-version", "5"])],
            linkerSettings: whisperLinkerSettings
        ),

        // The menu bar app
        .executableTarget(
            name: "desi-dictation",
            dependencies: ["DesiDictationKit"],
            path: "Sources/DesiDictationApp",
            swiftSettings: [.unsafeFlags(["-swift-version", "5"])]
        ),

        // Headless CLI for engine verification without mic/AX permissions
        .executableTarget(
            name: "desi-cli",
            dependencies: ["DesiDictationKit"],
            path: "Sources/DesiCLI",
            swiftSettings: [.unsafeFlags(["-swift-version", "5"])]
        ),

        // Assertion-based test runner (CLT has no XCTest — see BUILD_LOG).
        // Run: swift run desi-tests  → exit 0 = all green.
        .executableTarget(
            name: "desi-tests",
            dependencies: ["DesiDictationKit"],
            path: "Sources/DesiTests",
            swiftSettings: [.unsafeFlags(["-swift-version", "5"])]
        ),
    ],
    // Passed explicitly to force the `swiftLanguageModes:` init overload — the
    // CLT 6.3.3 ManifestAPI dylib doesn't export the deprecated
    // `swiftLanguageVersions:` overload its own swiftmodule advertises, and
    // default-argument overload resolution picks the missing one (FM#3 redux).
    swiftLanguageModes: [.v5]
)
