import AVFoundation
import Foundation
import Models

public enum PlaybackState: Sendable, Equatable {
    case stopped
    case playing
    case paused
}

public protocol PlaybackEngineProtocol: Sendable {
    var state: PlaybackState { get async }
    var currentBeat: Double { get async }
    func load(score: Score) async throws
    func play() async throws
    func pause() async
    func stop() async
    func setPartVolume(partIndex: Int, volume: Float) async
    func setPartMuted(partIndex: Int, muted: Bool) async
    func setTempo(_ bpm: Int) async
}

public actor PlaybackEngine: PlaybackEngineProtocol {
    private let engine: AVAudioEngine
    private let soundFontManager: SoundFontManagerProtocol
    private var samplers: [AVAudioUnitSampler] = []
    private var mixerNodes: [AVAudioMixerNode] = []

    private var schedule: MIDISchedule?
    private var score: Score?

    public private(set) var state: PlaybackState = .stopped
    public private(set) var currentBeat: Double = 0

    private var playbackTask: Task<Void, Never>?
    private var partVolumes: [Float] = []
    private var partMuted: [Bool] = []
    private var currentTempo: Int = 120

    public init(
        soundFontManager: SoundFontManagerProtocol = SoundFontManager()
    ) {
        self.engine = AVAudioEngine()
        self.soundFontManager = soundFontManager
    }

    public func load(score: Score) throws {
        stop()

        self.score = score
        self.currentTempo = score.tempo

        teardownAudioGraph()

        let scheduler = MIDIScheduler()
        self.schedule = scheduler.schedule(score: score)

        try setupAudioGraph(partCount: score.parts.count)

        if let sfURL = soundFontManager.soundFontURL {
            for (index, sampler) in samplers.enumerated() {
                let program = score.parts[index].midiProgram
                try sampler.loadSoundBankInstrument(
                    at: sfURL,
                    program: program,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                )
            }
        }

        partVolumes = Array(repeating: Float(1.0), count: score.parts.count)
        partMuted = Array(repeating: false, count: score.parts.count)
    }

    public func play() throws {
        guard let schedule, state != .playing else { return }

        if !engine.isRunning {
            try engine.start()
        }

        state = .playing

        playbackTask = Task { [weak self] in
            guard let self else { return }
            await self.runPlayback(schedule: schedule)
        }
    }

    public func pause() {
        state = .paused
        playbackTask?.cancel()
        playbackTask = nil
        allNotesOff()
    }

    public func stop() {
        state = .stopped
        playbackTask?.cancel()
        playbackTask = nil
        currentBeat = 0
        allNotesOff()
    }

    public func setPartVolume(partIndex: Int, volume: Float) {
        guard partIndex < partVolumes.count else { return }
        partVolumes[partIndex] = volume
        if partIndex < mixerNodes.count {
            mixerNodes[partIndex].outputVolume =
                partMuted[partIndex] ? 0 : volume
        }
    }

    public func setPartMuted(partIndex: Int, muted: Bool) {
        guard partIndex < partMuted.count else { return }
        partMuted[partIndex] = muted
        if partIndex < mixerNodes.count {
            mixerNodes[partIndex].outputVolume =
                muted ? 0 : partVolumes[partIndex]
        }
    }

    public func setTempo(_ bpm: Int) {
        currentTempo = max(40, min(300, bpm))
    }

    // MARK: - Audio Graph

    private func setupAudioGraph(partCount: Int) throws {
        samplers = []
        mixerNodes = []

        for _ in 0..<partCount {
            let sampler = AVAudioUnitSampler()
            let mixer = AVAudioMixerNode()

            engine.attach(sampler)
            engine.attach(mixer)
            engine.connect(
                sampler, to: mixer,
                format: nil
            )
            engine.connect(
                mixer, to: engine.mainMixerNode,
                format: nil
            )

            samplers.append(sampler)
            mixerNodes.append(mixer)
        }

        engine.prepare()
    }

    private func teardownAudioGraph() {
        if engine.isRunning {
            engine.stop()
        }
        for sampler in samplers {
            engine.detach(sampler)
        }
        for mixer in mixerNodes {
            engine.detach(mixer)
        }
        samplers = []
        mixerNodes = []
    }

    // MARK: - Playback Loop

    private func runPlayback(schedule: MIDISchedule) async {
        let events = schedule.events
        var activeNotes: [(partIndex: Int, note: UInt8, endBeat: Double)] = []
        var eventIndex = 0
        let startTime = Date()
        let startBeat = currentBeat

        while state == .playing, !Task.isCancelled {
            let elapsed = Date().timeIntervalSince(startTime)
            let beatsPerSecond = Double(currentTempo) / 60.0
            currentBeat = startBeat + elapsed * beatsPerSecond

            if currentBeat >= schedule.totalBeats {
                state = .stopped
                currentBeat = 0
                allNotesOff()
                return
            }

            // Start new notes
            while eventIndex < events.count,
                events[eventIndex].startBeat <= currentBeat
            {
                let event = events[eventIndex]
                if event.partIndex < samplers.count,
                    !partMuted[event.partIndex]
                {
                    samplers[event.partIndex].startNote(
                        event.midiNote,
                        withVelocity: event.velocity,
                        onChannel: 0
                    )
                    activeNotes.append((
                        partIndex: event.partIndex,
                        note: event.midiNote,
                        endBeat: event.endBeat
                    ))
                }
                eventIndex += 1
            }

            // End expired notes
            activeNotes.removeAll { active in
                if active.endBeat <= currentBeat {
                    if active.partIndex < samplers.count {
                        samplers[active.partIndex].stopNote(
                            active.note, onChannel: 0
                        )
                    }
                    return true
                }
                return false
            }

            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func allNotesOff() {
        for sampler in samplers {
            for note: UInt8 in 0...127 {
                sampler.stopNote(note, onChannel: 0)
            }
        }
    }
}
