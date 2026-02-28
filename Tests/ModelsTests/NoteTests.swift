import Foundation
import Testing

@testable import Models

@Suite("Note") struct NoteTests {
    @Test("Note with pitch") func noteWithPitch() {
        let note = Note(pitch: Pitch(step: .c, octave: 4), duration: 1.0, noteType: .quarter)
        #expect(note.pitch != nil)
        #expect(note.isRest == false)
        #expect(note.duration == 1.0)
    }

    @Test("Rest note has no pitch") func restNote() {
        let rest = Note(duration: 2.0, noteType: .half, isRest: true)
        #expect(rest.pitch == nil)
        #expect(rest.isRest == true)
    }

    @Test("Note with lyric") func noteWithLyric() {
        let note = Note(
            pitch: Pitch(step: .g, octave: 4), duration: 1.0,
            lyric: Lyric(text: "Wa", syllabic: .begin))
        #expect(note.lyric?.text == "Wa")
        #expect(note.lyric?.syllabic == .begin)
    }

    @Test("NoteType relative durations") func noteTypeDurations() {
        #expect(NoteType.whole.relativeDuration == 4.0)
        #expect(NoteType.half.relativeDuration == 2.0)
        #expect(NoteType.quarter.relativeDuration == 1.0)
        #expect(NoteType.eighth.relativeDuration == 0.5)
        #expect(NoteType.sixteenth.relativeDuration == 0.25)
    }

    @Test("Note is Codable round-trip") func codableRoundTrip() throws {
        let original = Note(
            pitch: Pitch(step: .a, alter: -1, octave: 3), duration: 0.5, noteType: .eighth,
            lyric: Lyric(text: "test", syllabic: .single), dynamic: .mf)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Note.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - Chord tests

    @Test("Chord creation with multiple pitches") func chordCreation() {
        let chord = Note(
            pitches: [
                Pitch(step: .c, octave: 4),
                Pitch(step: .e, octave: 4),
                Pitch(step: .g, octave: 4),
            ], duration: 1.0, noteType: .quarter)
        #expect(chord.pitches.count == 3)
        #expect(chord.isChord)
        #expect(chord.pitch?.step == .c)
    }

    @Test("Single-pitch note is not a chord") func singlePitchNotChord() {
        let note = Note(pitch: Pitch(step: .c, octave: 4), duration: 1.0)
        #expect(!note.isChord)
        #expect(note.pitches.count == 1)
    }

    @Test("Rest note is not a chord") func restNotChord() {
        let rest = Note(duration: 1.0, isRest: true)
        #expect(!rest.isChord)
        #expect(rest.pitches.isEmpty)
    }

    @Test("pitch accessor returns first pitch") func pitchAccessor() {
        let chord = Note(
            pitches: [Pitch(step: .e, octave: 4), Pitch(step: .g, octave: 4)], duration: 1.0)
        #expect(chord.pitch?.step == .e)
    }

    @Test("Backward-compat init wraps single pitch") func backwardCompatInit() {
        let note = Note(pitch: Pitch(step: .d, octave: 5), duration: 2.0, noteType: .half)
        #expect(note.pitches == [Pitch(step: .d, octave: 5)])
    }

    @Test("Backward-compat init with nil pitch") func backwardCompatNilPitch() {
        let note = Note(pitch: nil, duration: 1.0, isRest: true)
        #expect(note.pitches.isEmpty)
    }

    @Test("Chord Codable round-trip") func chordCodableRoundTrip() throws {
        let original = Note(
            pitches: [
                Pitch(step: .c, octave: 4),
                Pitch(step: .e, octave: 4),
                Pitch(step: .g, octave: 4),
            ], duration: 1.0, noteType: .quarter)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Note.self, from: data)
        #expect(decoded == original)
        #expect(decoded.pitches.count == 3)
    }

    @Test("Legacy JSON with single pitch key decodes correctly") func legacyJsonDecode() throws {
        let json = """
            {
                "id": "00000000-0000-0000-0000-000000000001",
                "pitch": {"step": "c", "alter": 0, "octave": 4},
                "duration": 1.0,
                "noteType": "quarter",
                "isRest": false,
                "isTied": false
            }
            """
        let decoded = try JSONDecoder().decode(Note.self, from: Data(json.utf8))
        #expect(decoded.pitches.count == 1)
        #expect(decoded.pitch?.step == .c)
        #expect(decoded.pitch?.octave == 4)
    }

    @Test("JSON with no pitch keys decodes as empty pitches") func noPitchKeysDecode() throws {
        let json = """
            {
                "id": "00000000-0000-0000-0000-000000000002",
                "duration": 2.0,
                "noteType": "half",
                "isRest": true,
                "isTied": false
            }
            """
        let decoded = try JSONDecoder().decode(Note.self, from: Data(json.utf8))
        #expect(decoded.pitches.isEmpty)
        #expect(decoded.pitch == nil)
    }
}
