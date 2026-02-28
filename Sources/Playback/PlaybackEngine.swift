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
    var totalBeats: Double { get async }
    func load(score: Score) async throws
    func play() async throws
    func pause() async
    func stop() async
    func seek(toBeat beat: Double) async throws
    func setPartVolume(partIndex: Int, volume: Float) async
    func setPartMuted(partIndex: Int, muted: Bool) async
    func setTempo(_ bpm: Int) async
}

public actor PlaybackEngine: PlaybackEngineProtocol {
    private let engine: AVAudioEngine
    private var samplers: [AVAudioUnitSampler] = []
    private var mixerNodes: [AVAudioMixerNode] = []

    private var schedule: MIDISchedule?
    private var score: Score?

    public private(set) var state: PlaybackState = .stopped
    public var totalBeats: Double { schedule?.totalBeats ?? 0 }

    private var sequencer: AVAudioSequencer?
    private var baseTempo: Double = 120
    private var _currentBeat: Double = 0
    private var monitorTask: Task<Void, Never>?

    public var currentBeat: Double {
        if state == .playing, let sequencer {
            return sequencer.currentPositionInBeats
        }
        return _currentBeat
    }

    private var partVolumes: [Float] = []
    private var partMuted: [Bool] = []
    private var currentTempo: Int = 120

    public init() {
        self.engine = AVAudioEngine()
    }

    public func load(score: Score) throws {
        stop()

        self.score = score
        self.currentTempo = score.tempo

        teardownAudioGraph()

        let scheduler = MIDIScheduler()
        self.schedule = scheduler.schedule(score: score)

        try setupAudioGraph(partCount: score.parts.count)
        loadSystemBank(score: score)
        try setupSequencer(partCount: score.parts.count)
        baseTempo = Double(score.tempo)

        partVolumes = Array(repeating: Float(1.0), count: score.parts.count)
        partMuted = Array(repeating: false, count: score.parts.count)
    }

    public func play() throws {
        guard let sequencer, state != .playing else { return }

        if !engine.isRunning { try engine.start() }

        sequencer.currentPositionInBeats = _currentBeat
        sequencer.rate = Float(Double(currentTempo) / baseTempo)
        try sequencer.start()

        state = .playing
        startMonitor()
    }

    public func pause() {
        guard let sequencer else { return }
        _currentBeat = sequencer.currentPositionInBeats
        sequencer.stop()
        monitorTask?.cancel()
        monitorTask = nil
        state = .paused
        allNotesOff()
    }

    public func stop() {
        sequencer?.stop()
        monitorTask?.cancel()
        monitorTask = nil
        state = .stopped
        _currentBeat = 0
        allNotesOff()
    }

    public func seek(toBeat beat: Double) throws {
        let clamped = max(0, min(beat, totalBeats))
        allNotesOff()
        _currentBeat = clamped

        if state == .playing {
            sequencer?.stop()
            monitorTask?.cancel()
            monitorTask = nil
            try play()
        } else if state == .stopped {
            state = .paused
        }
    }

    public func setPartVolume(partIndex: Int, volume: Float) {
        guard partIndex < partVolumes.count else { return }
        partVolumes[partIndex] = volume
        if partIndex < mixerNodes.count {
            mixerNodes[partIndex].outputVolume = partMuted[partIndex] ? 0 : volume
        }
    }

    public func setPartMuted(partIndex: Int, muted: Bool) {
        guard partIndex < partMuted.count else { return }
        partMuted[partIndex] = muted
        if partIndex < mixerNodes.count {
            mixerNodes[partIndex].outputVolume = muted ? 0 : partVolumes[partIndex]
        }
    }

    public func setTempo(_ bpm: Int) {
        currentTempo = max(40, min(300, bpm))
        if state == .playing, let sequencer {
            sequencer.rate = Float(Double(currentTempo) / baseTempo)
        }
    }

    // MARK: - Instrument loading

    #if os(macOS)
    private static let systemBankURL = URL(
        filePath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
    )
    #endif

    private func loadSystemBank(score: Score) {
        #if os(macOS)
        guard FileManager.default.fileExists(atPath: Self.systemBankURL.path()) else { return }
        for (index, sampler) in samplers.enumerated() {
            let program = score.parts[index].midiProgram
            try? sampler.loadSoundBankInstrument(
                at: Self.systemBankURL, program: program,
                bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                bankLSB: UInt8(kAUSampler_DefaultBankLSB))
        }
        #endif
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
            engine.connect(sampler, to: mixer, format: nil)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)

            samplers.append(sampler)
            mixerNodes.append(mixer)
        }

        engine.prepare()
    }

    private func setupSequencer(partCount: Int) throws {
        guard let schedule else { return }

        let midiData = try MIDIDataBuilder.buildSMFData(from: schedule, partCount: partCount)

        let seq = AVAudioSequencer(audioEngine: engine)
        try seq.load(from: midiData, options: [])

        // Route each part track to its corresponding sampler.
        // AVAudioSequencer.tracks excludes the tempo track, so
        // tracks[i] corresponds to part i.
        guard seq.tracks.count >= partCount else {
            throw ChoirHelperError.audioEngineError(
                "Expected \(partCount) sequencer tracks, got \(seq.tracks.count)")
        }
        for i in 0..<partCount {
            seq.tracks[i].destinationAudioUnit = samplers[i]
        }

        seq.prepareToPlay()
        self.sequencer = seq
    }

    private func teardownAudioGraph() {
        sequencer?.stop()
        sequencer = nil

        if engine.isRunning { engine.stop() }
        for sampler in samplers { engine.detach(sampler) }
        for mixer in mixerNodes { engine.detach(mixer) }
        samplers = []
        mixerNodes = []
    }

    // MARK: - End-of-playback monitor

    private func startMonitor() {
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                if await self.checkPlaybackEnd() { return }
            }
        }
    }

    private func checkPlaybackEnd() -> Bool {
        guard state == .playing else { return true }
        if let sequencer, !sequencer.isPlaying {
            state = .stopped
            _currentBeat = 0
            allNotesOff()
            return true
        }
        return false
    }

    private func allNotesOff() {
        for sampler in samplers {
            for note: UInt8 in 0...127 { sampler.stopNote(note, onChannel: 0) }
        }
    }
}
