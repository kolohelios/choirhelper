// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChoirHelper",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
    ],
    products: [
        .library(
            name: "ChoirHelperKit",
            targets: [
                "Models",
                "MusicXML",
                "OpenRouter",
                "SheetMusicOCR",
                "Playback",
                "Storage",
            ]
        )
    ],
    targets: [
        // App - SwiftUI app entry point
        .executableTarget(
            name: "App",
            dependencies: [
                "Models",
                "MusicXML",
                "OpenRouter",
                "Playback",
                "Storage",
                "Views",
            ],
            path: "Sources/App",
            resources: [
                .copy("../../Resources/ExamplePieces"),
            ]
        ),

        // Views - SwiftUI view components
        .target(
            name: "Views",
            dependencies: [
                "Models",
                "Playback",
                "Storage",
            ],
            path: "Sources/Views"
        ),

        // Models - Domain types (zero dependencies)
        .target(
            name: "Models",
            dependencies: [],
            path: "Sources/Models"
        ),

        // MusicXML - SAX parser for MusicXML files
        .target(
            name: "MusicXML",
            dependencies: ["Models"],
            path: "Sources/MusicXML"
        ),

        // OpenRouter - AI API client (BYOK)
        .target(
            name: "OpenRouter",
            dependencies: ["Models"],
            path: "Sources/OpenRouter"
        ),

        // SheetMusicOCR - Photo → MusicXML pipeline
        .target(
            name: "SheetMusicOCR",
            dependencies: ["OpenRouter", "Models"],
            path: "Sources/SheetMusicOCR"
        ),

        // Playback - AVAudioEngine-based MIDI playback
        .target(
            name: "Playback",
            dependencies: ["Models"],
            path: "Sources/Playback"
        ),

        // Storage - iCloud Documents persistence + Keychain
        .target(
            name: "Storage",
            dependencies: ["Models"],
            path: "Sources/Storage"
        ),

        // Tests
        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"],
            path: "Tests/ModelsTests"
        ),
        .testTarget(
            name: "MusicXMLTests",
            dependencies: ["MusicXML", "Models"],
            path: "Tests/MusicXMLTests"
        ),
        .testTarget(
            name: "OpenRouterTests",
            dependencies: ["OpenRouter", "Models"],
            path: "Tests/OpenRouterTests"
        ),
        .testTarget(
            name: "PlaybackTests",
            dependencies: ["Playback", "Models"],
            path: "Tests/PlaybackTests"
        ),
        .testTarget(
            name: "SheetMusicOCRTests",
            dependencies: ["SheetMusicOCR", "OpenRouter", "Models"],
            path: "Tests/SheetMusicOCRTests"
        ),
        .testTarget(
            name: "StorageTests",
            dependencies: ["Storage", "Models"],
            path: "Tests/StorageTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
