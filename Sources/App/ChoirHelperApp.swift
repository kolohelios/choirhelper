#if canImport(AppKit)
import AppKit
#endif
import Models
import MusicXML
import Playback
import Storage
import SwiftUI

@main public struct ChoirHelperApp: App {
    @State private var scoreLibrary: [Score] = []
    @State private var selectedScore: Score?

    public init() {
        #if canImport(AppKit)
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            ContentView(scores: $scoreLibrary, selectedScore: $selectedScore).task {
                await loadLibrary()
            }
        }
    }

    private func loadLibrary() async {
        let storage = ScoreStorage()
        let scores = (try? await storage.loadAll()) ?? []

        if scores.isEmpty {
            if let score = loadBundledExample() { scoreLibrary = [score] }
        } else {
            scoreLibrary = scores
        }
    }

    private func loadBundledExample() -> Score? {
        let bundle = Bundle.module
        guard
            let url = bundle.url(
                forResource: "ode_to_joy", withExtension: "musicxml",
                subdirectory: "ExamplePieces")
        else { return nil }

        let parser = MusicXMLParser()
        return try? parser.parse(contentsOf: url)
    }
}
