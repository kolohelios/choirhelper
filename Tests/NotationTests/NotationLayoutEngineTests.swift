import Testing

@testable import Models
@testable import Notation

@Suite("NotationLayoutEngine") struct NotationLayoutEngineTests {
    private func makePart(measures: [Measure], clefType: ClefType = .treble) -> Part {
        Part(
            name: "Test", partType: clefType == .bass ? .bass : .soprano, measures: measures,
            midiChannel: 0, midiProgram: 52)
    }

    private func makeMeasure(
        number: Int, noteCount: Int = 4, noteType: NoteType = .quarter,
        pitch: Pitch = Pitch(step: .c, octave: 5)
    ) -> Measure {
        let notes = (0..<noteCount).map { _ in
            Note(pitch: pitch, duration: noteType.relativeDuration, noteType: noteType)
        }
        return Measure(number: number, notes: notes)
    }

    @Test("Empty part produces empty layout") func emptyPart() {
        let part = makePart(measures: [])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)
        #expect(layout.lines.isEmpty)
    }

    @Test("Single measure fits on one line") func singleMeasure() {
        let part = makePart(measures: [makeMeasure(number: 1)])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)
        #expect(layout.lines.count == 1)
        #expect(layout.lines[0].measures.count == 1)
    }

    @Test("Multiple measures fill multiple lines") func multipleLines() {
        // Create 8 measures with 4 quarter notes each
        let measures = (1...8).map { makeMeasure(number: $0) }
        let part = makePart(measures: measures)
        let geo = StaffGeometry(clefType: .treble)
        // Narrow width forces line breaks
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 300)
        let layout = engine.layout(part: part)
        #expect(layout.lines.count > 1)
    }

    @Test("All measures are accounted for across lines") func allMeasuresPresent() {
        let measures = (1...6).map { makeMeasure(number: $0) }
        let part = makePart(measures: measures)
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 300)
        let layout = engine.layout(part: part)
        let totalMeasures = layout.lines.reduce(0) { $0 + $1.measures.count }
        #expect(totalMeasures == 6)
    }

    @Test("Beat positions are sequential across measures") func beatPositions() {
        let measures = (1...3).map { makeMeasure(number: $0) }
        let part = makePart(measures: measures)
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 800)
        let layout = engine.layout(part: part)

        // All measures on one line with wide width
        #expect(layout.lines.count == 1)
        let line = layout.lines[0]
        #expect(line.measures[0].startBeat == 0)
        #expect(line.measures[1].startBeat == 4.0)  // After 4 quarter notes
        #expect(line.measures[2].startBeat == 8.0)
    }

    @Test("Note X positions are within measure bounds") func noteXPositions() {
        let part = makePart(measures: [makeMeasure(number: 1)])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let measure = layout.lines[0].measures[0]
        for note in measure.notes {
            #expect(note.x >= measure.x)
            #expect(note.x <= measure.x + measure.width)
        }
    }

    @Test("Notes are ordered left to right") func noteOrdering() {
        let part = makePart(measures: [makeMeasure(number: 1)])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let notes = layout.lines[0].measures[0].notes
        for i in 1..<notes.count { #expect(notes[i].x > notes[i - 1].x) }
    }

    @Test("Rest notes are positioned at staff center") func restPositioning() {
        let restNote = Note(duration: 1.0, noteType: .quarter, isRest: true)
        let measure = Measure(number: 1, notes: [restNote])
        let part = makePart(measures: [measure])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let note = layout.lines[0].measures[0].notes[0]
        #expect(note.isRest)
        #expect(note.y == geo.staffHeight / 2)
    }

    @Test("Lyric text is preserved in layout") func lyricText() {
        let lyricNote = Note(
            pitch: Pitch(step: .c, octave: 5), duration: 1.0, noteType: .quarter,
            lyric: Lyric(text: "la"))
        let measure = Measure(number: 1, notes: [lyricNote])
        let part = makePart(measures: [measure])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        #expect(layout.lines[0].measures[0].notes[0].lyricText == "la")
    }

    @Test("Line start/end beats are consistent") func lineBeats() {
        let measures = (1...4).map { makeMeasure(number: $0) }
        let part = makePart(measures: measures)
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 300)
        let layout = engine.layout(part: part)

        // First line starts at beat 0
        #expect(layout.lines[0].startBeat == 0)

        // Each line's end matches the next line's start
        for i in 1..<layout.lines.count {
            #expect(layout.lines[i].startBeat == layout.lines[i - 1].endBeat)
        }
    }

    @Test("lineIndex(forBeat:) finds correct line") func lineIndexForBeat() {
        let measures = (1...4).map { makeMeasure(number: $0) }
        let part = makePart(measures: measures)
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 800)
        let layout = engine.layout(part: part)

        #expect(layout.lineIndex(forBeat: 0) == 0)
        #expect(layout.lineIndex(forBeat: 2.0) == 0)
    }

    @Test("Accidentals are preserved from pitch") func accidentals() {
        let sharpNote = Note(
            pitch: Pitch(step: .f, alter: 1, octave: 4), duration: 1.0, noteType: .quarter)
        let measure = Measure(number: 1, notes: [sharpNote])
        let part = makePart(measures: [measure])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        #expect(layout.lines[0].measures[0].notes[0].accidental == 1)
    }

    @Test("Very narrow width still produces layout with one measure per line") func narrowWidth() {
        let measures = (1...3).map { makeMeasure(number: $0) }
        let part = makePart(measures: measures)
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 50)
        let layout = engine.layout(part: part)

        // Each line should have at least one measure
        #expect(layout.lines.count == 3)
        for line in layout.lines { #expect(!line.measures.isEmpty) }
    }
}
