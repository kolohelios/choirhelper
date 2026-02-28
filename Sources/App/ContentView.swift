import Models
import SwiftUI
import Views

public struct ContentView: View {
    @Binding var scores: [Score]
    @Binding var selectedScore: Score?

    public init(scores: Binding<[Score]>, selectedScore: Binding<Score?>) {
        self._scores = scores
        self._selectedScore = selectedScore
    }

    public var body: some View {
        NavigationSplitView {
            LibraryListView(scores: scores, selectedScore: $selectedScore)
        } detail: {
            if let score = selectedScore {
                PracticeContainerView(score: score)
            } else {
                ContentUnavailableView(
                    "Select a Score", systemImage: "music.note.list",
                    description: Text("Choose a score from the library to start practicing"))
            }
        }
    }
}

private struct LibraryListView: View {
    let scores: [Score]
    @Binding var selectedScore: Score?

    var body: some View {
        List(scores, selection: $selectedScore) { score in
            VStack(alignment: .leading) {
                Text(score.title).font(.headline)
                if let composer = score.composer {
                    Text(composer).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    Label(score.keySignature.displayName, systemImage: "music.note")
                    Label(score.timeSignature.displayName, systemImage: "metronome")
                    Label("\(score.tempo) BPM", systemImage: "speedometer")
                }.font(.caption).foregroundStyle(.secondary)
            }.tag(score)
        }.navigationTitle("Library")
    }
}
