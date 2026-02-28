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

    // MARK: - Chord layout tests

    @Test("Chord has multiple Y positions") func chordMultipleYPositions() {
        let chord = Note(
            pitches: [
                Pitch(step: .c, octave: 5),
                Pitch(step: .e, octave: 5),
                Pitch(step: .g, octave: 5),
            ], duration: 1.0, noteType: .quarter)
        let measure = Measure(number: 1, notes: [chord])
        let part = makePart(measures: [measure])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let note = layout.lines[0].measures[0].notes[0]
        #expect(note.ys.count == 3)
        #expect(note.isChord)
        // Y positions should all be different
        #expect(Set(note.ys).count == 3)
    }

    @Test("Chord stem direction based on outermost pitches") func chordStemDirection() {
        // Chord spanning above middle line — stem should go down
        let highChord = Note(
            pitches: [
                Pitch(step: .a, octave: 5),
                Pitch(step: .c, octave: 6),
            ], duration: 1.0, noteType: .quarter)
        let measure1 = Measure(number: 1, notes: [highChord])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)

        let layout1 = engine.layout(part: makePart(measures: [measure1]))
        #expect(!layout1.lines[0].measures[0].notes[0].stemUp)

        // Chord spanning below middle line — stem should go up
        let lowChord = Note(
            pitches: [
                Pitch(step: .c, octave: 4),
                Pitch(step: .e, octave: 4),
            ], duration: 1.0, noteType: .quarter)
        let measure2 = Measure(number: 1, notes: [lowChord])
        let layout2 = engine.layout(part: makePart(measures: [measure2]))
        #expect(layout2.lines[0].measures[0].notes[0].stemUp)
    }

    @Test("Chord merges ledger lines from all pitches") func chordMergedLedgerLines() {
        // C4 and A3 both need ledger lines below treble staff
        let chord = Note(
            pitches: [
                Pitch(step: .c, octave: 4),
                Pitch(step: .a, octave: 3),
            ], duration: 1.0, noteType: .quarter)
        let measure = Measure(number: 1, notes: [chord])
        let part = makePart(measures: [measure])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let note = layout.lines[0].measures[0].notes[0]
        // Should have ledger lines (at least middle C line)
        #expect(!note.ledgerLineYs.isEmpty)
        // Ledger lines should be deduplicated and sorted
        #expect(note.ledgerLineYs == note.ledgerLineYs.sorted())
        #expect(Set(note.ledgerLineYs).count == note.ledgerLineYs.count)
    }

    // MARK: - Tenor octave transposition tests

    @Test("Tenor C3 with octave transposition renders at same Y as default C4")
    func tenorOctaveTransposition() {
        let c3 = Pitch(step: .c, octave: 3)
        let c4 = Pitch(step: .c, octave: 4)
        let tenorGeo = StaffGeometry(clefType: .treble, octaveTransposition: 1)
        let defaultGeo = StaffGeometry(clefType: .treble)
        #expect(tenorGeo.yPosition(for: c3) == defaultGeo.yPosition(for: c4))
    }

    // MARK: - Reverse beat lookup tests

    @Test("beatPosition(forX:) returns start beat for first note X") func beatPositionFirstNote() {
        let part = makePart(measures: [makeMeasure(number: 1)])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let line = layout.lines[0]
        let firstNote = line.measures[0].notes[0]
        let beat = line.beatPosition(forX: firstNote.x)
        #expect(beat != nil)
        #expect(abs(beat! - firstNote.beatPosition) < 0.01)
    }

    @Test("beatPosition(forX:) interpolates within measure") func beatPositionInterpolation() {
        let part = makePart(measures: [makeMeasure(number: 1)])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let line = layout.lines[0]
        let notes = line.measures[0].notes
        guard notes.count >= 2 else { return }

        // Midpoint between first and second note
        let midX = (notes[0].x + notes[1].x) / 2
        let beat = line.beatPosition(forX: midX)
        #expect(beat != nil)
        // Should be between the two notes' beat positions
        #expect(beat! > notes[0].beatPosition)
        #expect(beat! < notes[1].beatPosition)
    }

    @Test("beatPosition(forX:) returns nil outside line bounds") func beatPositionOutsideBounds() {
        let part = makePart(measures: [makeMeasure(number: 1)])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let line = layout.lines[0]
        // Way past the right edge
        let beat = line.beatPosition(forX: 10000)
        #expect(beat == nil)

        // Before the measure start
        let beatNeg = line.beatPosition(forX: -100)
        #expect(beatNeg == nil)
    }

    @Test("Chord accidentals are per-pitch") func chordAccidentals() {
        let chord = Note(
            pitches: [
                Pitch(step: .c, octave: 4),
                Pitch(step: .e, alter: -1, octave: 4),
                Pitch(step: .g, alter: 1, octave: 4),
            ], duration: 1.0, noteType: .quarter)
        let measure = Measure(number: 1, notes: [chord])
        let part = makePart(measures: [measure])
        let geo = StaffGeometry(clefType: .treble)
        let engine = NotationLayoutEngine(staffGeometry: geo, availableWidth: 400)
        let layout = engine.layout(part: part)

        let note = layout.lines[0].measures[0].notes[0]
        #expect(note.accidentals.count == 3)
        #expect(note.accidentals[0] == 0)   // C natural
        #expect(note.accidentals[1] == -1)  // Eb
        #expect(note.accidentals[2] == 1)   // G#
    }
}
