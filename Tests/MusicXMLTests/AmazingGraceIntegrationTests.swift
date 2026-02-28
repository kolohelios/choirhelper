import Foundation
import Testing

@testable import Models
@testable import MusicXML

@Suite("Amazing Grace Integration") struct AmazingGraceIntegrationTests {
    let parser = MusicXMLParser()

    func loadAmazingGrace() throws -> Score {
        let testFile = #filePath
        // Navigate up: MusicXMLTests/ -> Tests/ -> project root
        let projectRoot = URL(fileURLWithPath: testFile).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let xmlURL = projectRoot.appendingPathComponent("Resources").appendingPathComponent(
            "ExamplePieces"
        ).appendingPathComponent("amazing_grace.musicxml")
        let data = try Data(contentsOf: xmlURL)
        return try parser.parse(data: data)
    }

    @Test("Parses Amazing Grace successfully") func parsesSuccessfully() throws {
        let score = try loadAmazingGrace()
        #expect(score.title == "Amazing Grace")
    }

    @Test("Has five parts: SATB + Piano") func hasFiveParts() throws {
        let score = try loadAmazingGrace()
        #expect(score.parts.count == 5)
        #expect(score.parts[0].partType == .soprano)
        #expect(score.parts[1].partType == .alto)
        #expect(score.parts[2].partType == .tenor)
        #expect(score.parts[3].partType == .bass)
        #expect(score.parts[4].partType == .piano)
    }

    @Test("Key signature is G major (1 sharp)") func keySignature() throws {
        let score = try loadAmazingGrace()
        #expect(score.keySignature.fifths == 1)
        #expect(score.keySignature.mode == .major)
    }

    @Test("Time signature is 3/4") func timeSignature() throws {
        let score = try loadAmazingGrace()
        #expect(score.timeSignature.beats == 3)
        #expect(score.timeSignature.beatType == 4)
    }

    @Test("Tempo is 100 BPM") func tempo() throws {
        let score = try loadAmazingGrace()
        #expect(score.tempo == 100)
    }

    @Test("Soprano has 16 measures") func sopranoMeasureCount() throws {
        let score = try loadAmazingGrace()
        #expect(score.parts[0].measures.count == 16)
    }

    @Test("All parts have same number of measures") func allPartsEqualMeasures() throws {
        let score = try loadAmazingGrace()
        let expected = score.parts[0].measures.count
        for part in score.parts {
            #expect(
                part.measures.count == expected,
                "\(part.name) has \(part.measures.count) measures, expected \(expected)")
        }
    }

    @Test("Soprano first real note is G4") func sopranoFirstNote() throws {
        let score = try loadAmazingGrace()
        // Measure 2 has the first full note (measure 1 is pickup)
        let firstFullMeasure = score.parts[0].measures[1]
        let firstNote = firstFullMeasure.notes[0]
        #expect(firstNote.pitch?.step == .g)
        #expect(firstNote.pitch?.octave == 4)
    }

    @Test("Soprano has lyrics") func sopranoHasLyrics() throws {
        let score = try loadAmazingGrace()
        let soprano = score.parts[0]
        let notesWithLyrics = soprano.measures.flatMap(\.notes).filter { $0.lyric != nil }
        #expect(notesWithLyrics.count > 10)
    }

    @Test("Four vocal parts and one accompaniment") func partClassification() throws {
        let score = try loadAmazingGrace()
        #expect(score.vocalParts.count == 4)
        #expect(score.accompanimentParts.count == 1)
    }
}
