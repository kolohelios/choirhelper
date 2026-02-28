import Models
import Notation
import Playback
import SwiftUI

public struct PracticeContainerView: View {
    let score: Score
    @State private var playbackState: PlaybackState = .stopped
    @State private var currentBeat: Double = 0
    @State private var partVolumes: [Float] = []
    @State private var partMuted: [Bool] = []
    @State private var tempo: Int = 120
    @State private var engine: PlaybackEngine?
    @State private var errorMessage: String?

    public init(score: Score) { self.score = score }

    public var body: some View {
        VStack(spacing: 0) {
            scoreHeader
            Divider()
            NotationPracticeView(score: score, currentBeat: currentBeat)
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    transportControls
                    tempoControl
                    volumeControls
                }.padding()
            }
        }.navigationTitle(score.title).task { await setupEngine() }.alert(
            "Playback Error",
            isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var scoreHeader: some View {
        HStack {
            VStack(alignment: .leading) {
                if let composer = score.composer {
                    Text(composer).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label(score.keySignature.displayName, systemImage: "music.note")
                    Label(score.timeSignature.displayName, systemImage: "metronome")
                    Label("\(score.parts.count) parts", systemImage: "person.3")
                }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }.padding()
    }

    private var transportControls: some View {
        HStack(spacing: 24) {
            Button {
                Task { await stopPlayback() }
            } label: {
                Image(systemName: "stop.fill").font(.title2)
            }.disabled(playbackState == .stopped)

            Button {
                Task { await togglePlayback() }
            } label: {
                Image(systemName: playbackState == .playing ? "pause.fill" : "play.fill").font(
                    .largeTitle)
            }

            Text(formatBeat(currentBeat)).font(.system(.title3, design: .monospaced))
                .foregroundStyle(.secondary)
        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var tempoControl: some View {
        VStack(alignment: .leading) {
            Text("Tempo: \(tempo) BPM").font(.headline)
            Slider(
                value: Binding(
                    get: { Double(tempo) },
                    set: { newVal in
                        tempo = Int(newVal)
                        Task { await engine?.setTempo(tempo) }
                    }), in: 40...300, step: 1)
        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var volumeControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Part Volumes").font(.headline)

            ForEach(Array(score.parts.enumerated()), id: \.offset) { index, part in
                HStack {
                    Button {
                        toggleMute(index: index)
                    } label: {
                        Image(
                            systemName: partMuted.indices.contains(index) && partMuted[index]
                                ? "speaker.slash.fill" : "speaker.wave.2.fill"
                        ).foregroundStyle(
                            score.userPartTypes.contains(part.partType)
                                ? Color.accentColor : Color.secondary)
                    }.buttonStyle(.plain)

                    Text(part.name).font(.subheadline).frame(width: 80, alignment: .leading)

                    Slider(
                        value: Binding(
                            get: {
                                Double(
                                    partVolumes.indices.contains(index) ? partVolumes[index] : 1.0)
                            }, set: { newVal in setVolume(index: index, volume: Float(newVal)) }),
                        in: 0...1)
                }
            }
        }.padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Engine

    private func setupEngine() async {
        let newEngine = PlaybackEngine()
        do {
            try await newEngine.load(score: score)
            engine = newEngine
            tempo = score.tempo
            partVolumes = Array(repeating: Float(1.0), count: score.parts.count)
            partMuted = Array(repeating: false, count: score.parts.count)
        } catch { errorMessage = error.localizedDescription }
    }

    private func togglePlayback() async {
        guard let engine else { return }
        let currentState = await engine.state
        do {
            if currentState == .playing {
                await engine.pause()
                playbackState = .paused
            } else {
                try await engine.play()
                playbackState = .playing
                startBeatTracking()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func stopPlayback() async {
        guard let engine else { return }
        await engine.stop()
        playbackState = .stopped
        currentBeat = 0
    }

    private func toggleMute(index: Int) {
        guard partMuted.indices.contains(index) else { return }
        partMuted[index].toggle()
        Task { await engine?.setPartMuted(partIndex: index, muted: partMuted[index]) }
    }

    private func setVolume(index: Int, volume: Float) {
        guard partVolumes.indices.contains(index) else { return }
        partVolumes[index] = volume
        Task { await engine?.setPartVolume(partIndex: index, volume: volume) }
    }

    private func startBeatTracking() {
        Task {
            while playbackState == .playing {
                if let engine {
                    currentBeat = await engine.currentBeat
                    let state = await engine.state
                    if state != .playing { playbackState = state }
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    private func formatBeat(_ beat: Double) -> String {
        let measureNum = Int(beat / Double(score.timeSignature.beats)) + 1
        let beatInMeasure =
            Int(beat.truncatingRemainder(dividingBy: Double(score.timeSignature.beats))) + 1
        return "m.\(measureNum) beat \(beatInMeasure)"
    }
}
