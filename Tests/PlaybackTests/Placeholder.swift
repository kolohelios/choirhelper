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
