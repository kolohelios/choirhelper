import Models
import MusicXML
import Playback
import Storage
import SwiftUI

@main
public struct ChoirHelperApp: App {
    @State private var scoreLibrary: [Score] = []
    @State private var selectedScore: Score?

    public init() {}

    public var body: some Scene {
        WindowGroup {
            ContentView(
                scores: $scoreLibrary,
                selectedScore: $selectedScore
            )
            .task {
                await loadLibrary()
            }
        }
    }

    private func loadLibrary() async {
        let storage = ScoreStorage()
        let scores = (try? await storage.loadAll()) ?? []

        if scores.isEmpty {
            // Load bundled Amazing Grace
            if let score = loadBundledAmazingGrace() {
                scoreLibrary = [score]
            }
        } else {
            scoreLibrary = scores
        }
    }

    private func loadBundledAmazingGrace() -> Score? {
        guard let url = Bundle.main.url(
            forResource: "amazing_grace",
            withExtension: "musicxml"
        ) else { return nil }

        let parser = MusicXMLParser()
        return try? parser.parse(contentsOf: url)
    }
}
