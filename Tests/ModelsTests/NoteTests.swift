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
}
