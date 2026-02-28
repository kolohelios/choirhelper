import Foundation
import Testing

@testable import Models

@Suite("Score") struct ScoreTests {
    static func makeTenorMeasure() -> Measure {
        Measure(
            number: 1,
            notes: [
                Note(pitch: Pitch(step: .c, octave: 4), duration: 1.0, noteType: .quarter),
                Note(pitch: Pitch(step: .d, octave: 4), duration: 1.0, noteType: .quarter),
                Note(pitch: Pitch(step: .e, octave: 4), duration: 1.0, noteType: .quarter),
                Note(pitch: Pitch(step: .f, octave: 4), duration: 1.0, noteType: .quarter),
            ])
    }

    static func makeScore() -> Score {
        let tenorPart = Part(
            name: "Tenor", partType: .tenor, measures: [makeTenorMeasure()], midiChannel: 2,
            midiProgram: 52)
        let pianoPart = Part(
            name: "Piano", partType: .piano, measures: [makeTenorMeasure()], midiChannel: 0,
            midiProgram: 0)
        return Score(
            title: "Test Score", composer: "Test Composer", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120,
            parts: [tenorPart, pianoPart], userPartTypes: [.tenor])
    }

    @Test("Score identifies vocal parts") func vocalParts() {
        let score = ScoreTests.makeScore()
        #expect(score.vocalParts.count == 1)
        #expect(score.vocalParts.first?.partType == .tenor)
    }

    @Test("Score identifies accompaniment parts") func accompanimentParts() {
        let score = ScoreTests.makeScore()
        #expect(score.accompanimentParts.count == 1)
        #expect(score.accompanimentParts.first?.partType == .piano)
    }

    @Test("Score identifies user parts") func userParts() {
        let score = ScoreTests.makeScore()
        #expect(score.userParts.count == 1)
        #expect(score.userParts.first?.name == "Tenor")
    }

    @Test("Score measure count from first part") func measureCount() {
        let score = ScoreTests.makeScore()
        #expect(score.measureCount == 1)
    }

    @Test("Score calculates duration in seconds") func durationSeconds() {
        let score = ScoreTests.makeScore()
        // 4 quarter notes at 120 BPM = 2 seconds
        #expect(abs(score.durationSeconds - 2.0) < 0.01)
    }

    @Test("Score is Codable round-trip") func codableRoundTrip() throws {
        let original = ScoreTests.makeScore()
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Score.self, from: data)
        #expect(decoded.title == original.title)
        #expect(decoded.composer == original.composer)
        #expect(decoded.tempo == original.tempo)
        #expect(decoded.parts.count == original.parts.count)
    }

    @Test("Empty score has zero duration") func emptyScoreZeroDuration() {
        let score = Score(
            title: "Empty", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120, parts: [])
        #expect(score.durationSeconds == 0)
    }
}
