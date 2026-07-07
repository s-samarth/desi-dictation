// swift-tools-version: 6.0
// NOTE: tools-version must be >= 6.0 — the CLT 6.3 ManifestAPI cannot link older
// manifest ABIs (see docs/BUILD_LOG.md failure mode #3). Language mode stays v5.
// Desi Dictation — SwiftPM package (no Xcode project; built with CLT only).
// whisper.cpp is linked as prebuilt static libs staged by scripts/setup_whisper.sh
// into ./Libraries and ./Sources/CWhisper/include.
import PackageDescription

let whisperLinkerSettings: [LinkerSetting] = [
    .unsafeFlags(["-L\(Context.packageDirectory)/Libraries"]),
    .linkedLibrary("whisper"),
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
    ]
)
