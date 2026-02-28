import AudioToolbox
import Foundation
import Testing

@testable import Models
@testable import Playback

@Suite("MIDIScheduler") struct MIDISchedulerTests {
    let scheduler = MIDIScheduler()

    static func simpleScore() -> Score {
        let measure = Measure(
            number: 1,
            notes: [
                Note(pitch: Pitch(step: .c, octave: 4), duration: 1.0, noteType: .quarter),
                Note(pitch: Pitch(step: .d, octave: 4), duration: 1.0, noteType: .quarter),
                Note(duration: 1.0, noteType: .quarter, isRest: true),
                Note(pitch: Pitch(step: .e, octave: 4), duration: 1.0, noteType: .quarter),
            ])
        let part = Part(
            name: "Soprano", partType: .soprano, measures: [measure], midiChannel: 0,
            midiProgram: 52)
        return Score(
            title: "Test", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120, parts: [part])
    }

    @Test("Generates events for non-rest notes only") func generatesEventsForNotes() {
        let schedule = scheduler.schedule(score: MIDISchedulerTests.simpleScore())
        // 3 pitched notes, 1 rest = 3 events
        #expect(schedule.events.count == 3)
    }

    @Test("Events are sorted by start beat") func eventsSortedByStartBeat() {
        let schedule = scheduler.schedule(score: MIDISchedulerTests.simpleScore())
        for i in 1..<schedule.events.count {
            #expect(schedule.events[i].startBeat >= schedule.events[i - 1].startBeat)
        }
    }

    @Test("Total beats matches sum of durations") func totalBeatsCorrect() {
        let schedule = scheduler.schedule(score: MIDISchedulerTests.simpleScore())
        #expect(schedule.totalBeats == 4.0)
    }

    @Test("Total seconds calculated from tempo") func totalSecondsFromTempo() {
        let schedule = scheduler.schedule(score: MIDISchedulerTests.simpleScore())
        // 4 beats at 120 BPM = 2 seconds
        #expect(abs(schedule.totalSeconds - 2.0) < 0.01)
    }

    @Test("MIDI note numbers are correct") func midiNoteNumbers() {
        let schedule = scheduler.schedule(score: MIDISchedulerTests.simpleScore())
        #expect(schedule.events[0].midiNote == 60)  // C4
        #expect(schedule.events[1].midiNote == 62)  // D4
        #expect(schedule.events[2].midiNote == 64)  // E4
    }

    @Test("Event start beats are sequential") func eventStartBeatsSequential() {
        let schedule = scheduler.schedule(score: MIDISchedulerTests.simpleScore())
        #expect(schedule.events[0].startBeat == 0.0)  // C4
        #expect(schedule.events[1].startBeat == 1.0)  // D4
        #expect(schedule.events[2].startBeat == 3.0)  // E4 (after rest)
    }

    @Test("Multi-part score generates events for all parts") func multiPartEvents() {
        let measure = Measure(
            number: 1,
            notes: [Note(pitch: Pitch(step: .c, octave: 4), duration: 4.0, noteType: .whole)])
        let score = Score(
            title: "Two Parts", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120,
            parts: [
                Part(
                    name: "Soprano", partType: .soprano, measures: [measure], midiChannel: 0,
                    midiProgram: 52),
                Part(
                    name: "Alto", partType: .alto, measures: [measure], midiChannel: 1,
                    midiProgram: 52),
            ])
        let schedule = scheduler.schedule(score: score)
        #expect(schedule.events.count == 2)
        let partIndices = Set(schedule.events.map(\.partIndex))
        #expect(partIndices == [0, 1])
    }

    @Test("Chord produces one event per pitch at same start beat") func chordEvents() {
        let measure = Measure(
            number: 1,
            notes: [
                Note(
                    pitches: [
                        Pitch(step: .c, octave: 4),
                        Pitch(step: .e, octave: 4),
                        Pitch(step: .g, octave: 4),
                    ], duration: 1.0, noteType: .quarter)
            ])
        let score = Score(
            title: "Chord", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120,
            parts: [
                Part(
                    name: "Piano", partType: .piano, measures: [measure], midiChannel: 0,
                    midiProgram: 0)
            ])
        let schedule = scheduler.schedule(score: score)
        #expect(schedule.events.count == 3)
        // All events at same start beat
        #expect(schedule.events.allSatisfy { $0.startBeat == 0.0 })
        let midiNotes = Set(schedule.events.map(\.midiNote))
        #expect(midiNotes == [60, 64, 67])  // C4, E4, G4
    }

    @Test("Chord does not inflate total beats") func chordTotalBeats() {
        let measure = Measure(
            number: 1,
            notes: [
                Note(
                    pitches: [
                        Pitch(step: .c, octave: 4),
                        Pitch(step: .e, octave: 4),
                    ], duration: 2.0, noteType: .half),
                Note(pitch: Pitch(step: .g, octave: 4), duration: 2.0, noteType: .half),
            ])
        let score = Score(
            title: "Chord", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120,
            parts: [
                Part(
                    name: "Piano", partType: .piano, measures: [measure], midiChannel: 0,
                    midiProgram: 0)
            ])
        let schedule = scheduler.schedule(score: score)
        #expect(schedule.totalBeats == 4.0)
    }

    @Test("Dynamic affects velocity") func dynamicAffectsVelocity() {
        let measure = Measure(
            number: 1,
            notes: [
                Note(pitch: Pitch(step: .c, octave: 4), duration: 1.0, dynamic: .pp),
                Note(pitch: Pitch(step: .d, octave: 4), duration: 1.0, dynamic: .ff),
            ])
        let score = Score(
            title: "Dynamics", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120,
            parts: [
                Part(
                    name: "S", partType: .soprano, measures: [measure], midiChannel: 0,
                    midiProgram: 52)
            ])
        let schedule = scheduler.schedule(score: score)
        #expect(schedule.events[0].velocity < schedule.events[1].velocity)
    }
}

@Suite("MIDIEvent") struct MIDIEventTests {
    @Test("End beat is start plus duration") func endBeat() {
        let event = MIDIEvent(
            partIndex: 0, midiNote: 60, velocity: 80, startBeat: 2.0, durationBeats: 1.5,
            measureNumber: 1, noteIndex: 0)
        #expect(event.endBeat == 3.5)
    }
}

@Suite("PlaybackState") struct PlaybackStateTests {
    @Test("States are equatable") func statesEquatable() {
        #expect(PlaybackState.stopped == PlaybackState.stopped)
        #expect(PlaybackState.playing != PlaybackState.paused)
    }
}

@Suite("MIDISchedule.eventIndex") struct MIDIScheduleEventIndexTests {
    static func makeSchedule() -> MIDISchedule {
        let events = [
            MIDIEvent(
                partIndex: 0, midiNote: 60, velocity: 80, startBeat: 0.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 0),
            MIDIEvent(
                partIndex: 0, midiNote: 62, velocity: 80, startBeat: 1.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 1),
            MIDIEvent(
                partIndex: 0, midiNote: 64, velocity: 80, startBeat: 2.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 2),
            MIDIEvent(
                partIndex: 0, midiNote: 65, velocity: 80, startBeat: 3.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 3),
        ]
        return MIDISchedule(events: events, totalBeats: 4.0, tempo: 120)
    }

    @Test("Finds first event at exact beat boundary") func exactBoundary() {
        let schedule = MIDIScheduleEventIndexTests.makeSchedule()
        #expect(schedule.eventIndex(forBeat: 0.0) == 0)
        #expect(schedule.eventIndex(forBeat: 2.0) == 2)
    }

    @Test("Finds next event for mid-beat position") func midBeat() {
        let schedule = MIDIScheduleEventIndexTests.makeSchedule()
        #expect(schedule.eventIndex(forBeat: 1.5) == 2)
    }

    @Test("Returns events.count when past all events") func pastEnd() {
        let schedule = MIDIScheduleEventIndexTests.makeSchedule()
        #expect(schedule.eventIndex(forBeat: 10.0) == 4)
    }

    @Test("Returns 0 for beat 0") func beatZero() {
        let schedule = MIDIScheduleEventIndexTests.makeSchedule()
        #expect(schedule.eventIndex(forBeat: 0.0) == 0)
    }
}

@Suite("MIDISchedule.eventIndex — seek support") struct MIDIScheduleSeekTests {
    private static func makeSchedule() -> MIDISchedule {
        MIDIScheduleEventIndexTests.makeSchedule()
    }

    @Test("eventIndex skips past played events on seek") func seekSkipsPlayed() {
        let schedule = MIDIScheduleSeekTests.makeSchedule()
        // Seeking to beat 2.5 means events at beats 0, 1, 2 are in the past
        let idx = schedule.eventIndex(forBeat: 2.5)
        #expect(idx == 3)
        // The event at this index is beat 3.0
        #expect(schedule.events[idx].startBeat == 3.0)
    }

    @Test("eventIndex at start returns 0") func seekToStart() {
        let schedule = MIDIScheduleSeekTests.makeSchedule()
        #expect(schedule.eventIndex(forBeat: 0.0) == 0)
    }

    @Test("eventIndex at end returns count") func seekToEnd() {
        let schedule = MIDIScheduleSeekTests.makeSchedule()
        #expect(schedule.eventIndex(forBeat: schedule.totalBeats) == schedule.events.count)
    }
}

@Suite("MIDIDataBuilder") struct MIDIDataBuilderTests {
    static func simpleSchedule() -> MIDISchedule {
        let events = [
            MIDIEvent(
                partIndex: 0, midiNote: 60, velocity: 80, startBeat: 0.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 0),
            MIDIEvent(
                partIndex: 0, midiNote: 62, velocity: 80, startBeat: 1.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 1),
        ]
        return MIDISchedule(events: events, totalBeats: 2.0, tempo: 120)
    }

    @Test("Builds non-empty Data from a simple schedule") func buildsNonEmptyData() throws {
        let data = try MIDIDataBuilder.buildSMFData(
            from: MIDIDataBuilderTests.simpleSchedule(), partCount: 1)
        #expect(!data.isEmpty)
    }

    @Test("Multi-part schedule produces correct track count") func multiPartTrackCount() throws {
        let events = [
            MIDIEvent(
                partIndex: 0, midiNote: 60, velocity: 80, startBeat: 0.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 0),
            MIDIEvent(
                partIndex: 1, midiNote: 64, velocity: 80, startBeat: 0.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 0),
            MIDIEvent(
                partIndex: 2, midiNote: 67, velocity: 80, startBeat: 0.0, durationBeats: 1.0,
                measureNumber: 1, noteIndex: 0),
        ]
        let schedule = MIDISchedule(events: events, totalBeats: 1.0, tempo: 100)
        let data = try MIDIDataBuilder.buildSMFData(from: schedule, partCount: 3)

        // Round-trip through MusicSequence to verify track count
        var sequence: MusicSequence?
        NewMusicSequence(&sequence)
        defer { if let sequence { DisposeMusicSequence(sequence) } }
        let status = MusicSequenceFileLoadData(sequence!, data as CFData, .midiType, [])
        #expect(status == noErr)

        var trackCount: UInt32 = 0
        MusicSequenceGetTrackCount(sequence!, &trackCount)
        #expect(trackCount == 3)
    }

    @Test("Tempo is embedded correctly") func tempoEmbedded() throws {
        let schedule = MIDISchedule(events: [], totalBeats: 0, tempo: 96)
        let data = try MIDIDataBuilder.buildSMFData(from: schedule, partCount: 0)

        var sequence: MusicSequence?
        NewMusicSequence(&sequence)
        defer { if let sequence { DisposeMusicSequence(sequence) } }
        MusicSequenceFileLoadData(sequence!, data as CFData, .midiType, [])

        var tempoTrack: MusicTrack?
        MusicSequenceGetTempoTrack(sequence!, &tempoTrack)

        var iterator: MusicEventIterator?
        NewMusicEventIterator(tempoTrack!, &iterator)
        defer { if let iterator { DisposeMusicEventIterator(iterator) } }

        var hasEvent: DarwinBoolean = false
        MusicEventIteratorHasCurrentEvent(iterator!, &hasEvent)
        #expect(hasEvent.boolValue)

        var timestamp: MusicTimeStamp = 0
        var eventType: MusicEventType = 0
        var eventData: UnsafeRawPointer?
        var eventDataSize: UInt32 = 0
        MusicEventIteratorGetEventInfo(
            iterator!, &timestamp, &eventType, &eventData, &eventDataSize)
        #expect(timestamp == 0)
        #expect(eventType == kMusicEventType_ExtendedTempo)
        if eventType == kMusicEventType_ExtendedTempo {
            let tempo = eventData!.load(as: ExtendedTempoEvent.self)
            #expect(abs(tempo.bpm - 96.0) < 0.01)
        }
    }

    @Test("Empty schedule produces valid data") func emptyScheduleValid() throws {
        let schedule = MIDISchedule(events: [], totalBeats: 0, tempo: 120)
        let data = try MIDIDataBuilder.buildSMFData(from: schedule, partCount: 0)
        #expect(!data.isEmpty)
    }
}

@Suite("PlaybackEngine — no audio") struct PlaybackEngineNoAudioTests {
    @Test("totalBeats is zero before loading") func totalBeatsEmpty() async {
        let engine = PlaybackEngine()
        let total = await engine.totalBeats
        #expect(total == 0)
    }

    @Test("Initial state is stopped") func initialState() async {
        let engine = PlaybackEngine()
        let state = await engine.state
        #expect(state == .stopped)
    }
}
