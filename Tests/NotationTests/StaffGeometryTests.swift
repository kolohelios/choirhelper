import Testing

@testable import Models
@testable import Notation

@Suite("StaffGeometry") struct StaffGeometryTests {
    @Test("Diatonic index for C4 is 28") func diatonicIndexC4() {
        let c4 = Pitch(step: .c, octave: 4)
        #expect(StaffGeometry.diatonicIndex(for: c4) == 28)
    }

    @Test("Diatonic index for A4 is 33") func diatonicIndexA4() {
        let a4 = Pitch(step: .a, octave: 4)
        #expect(StaffGeometry.diatonicIndex(for: a4) == 33)
    }

    @Test("Diatonic index for F5 is 38") func diatonicIndexF5() {
        let f5 = Pitch(step: .f, octave: 5)
        #expect(StaffGeometry.diatonicIndex(for: f5) == 38)
    }

    @Test("Octave adds 7 to diatonic index") func diatonicIndexOctave() {
        let c3 = Pitch(step: .c, octave: 3)
        let c4 = Pitch(step: .c, octave: 4)
        #expect(StaffGeometry.diatonicIndex(for: c4) - StaffGeometry.diatonicIndex(for: c3) == 7)
    }

    @Test("Treble clef top line F5 is at Y=0") func trebleTopLine() {
        let geo = StaffGeometry(clefType: .treble)
        let f5 = Pitch(step: .f, octave: 5)
        #expect(geo.yPosition(for: f5) == 0)
    }

    @Test("Treble clef bottom line E4 is at staff height") func trebleBottomLine() {
        let geo = StaffGeometry(clefType: .treble)
        let e4 = Pitch(step: .e, octave: 4)
        #expect(geo.yPosition(for: e4) == geo.staffHeight)
    }

    @Test("Bass clef top line A3 is at Y=0") func bassTopLine() {
        let geo = StaffGeometry(clefType: .bass)
        let a3 = Pitch(step: .a, octave: 3)
        #expect(geo.yPosition(for: a3) == 0)
    }

    @Test("Bass clef bottom line G2 is at staff height") func bassBottomLine() {
        let geo = StaffGeometry(clefType: .bass)
        let g2 = Pitch(step: .g, octave: 2)
        #expect(geo.yPosition(for: g2) == geo.staffHeight)
    }

    @Test("Staff height is four times spacing") func staffHeight() {
        let geo = StaffGeometry(staffSpacing: 10.0, clefType: .treble)
        #expect(geo.staffHeight == 40.0)
    }

    @Test("Middle C needs one ledger line in treble clef") func middleCLedgerTreble() {
        let geo = StaffGeometry(clefType: .treble)
        let c4 = Pitch(step: .c, octave: 4)
        let ledgers = geo.ledgerLineYPositions(for: c4)
        #expect(ledgers.count == 1)
    }

    @Test("A3 needs two ledger lines in treble clef") func a3LedgerTreble() {
        let geo = StaffGeometry(clefType: .treble)
        let a3 = Pitch(step: .a, octave: 3)
        let ledgers = geo.ledgerLineYPositions(for: a3)
        #expect(ledgers.count == 2)
    }

    @Test("D4 needs no ledger lines in treble clef") func d4NoLedgerTreble() {
        let geo = StaffGeometry(clefType: .treble)
        let d4 = Pitch(step: .d, octave: 4)
        #expect(geo.ledgerLineYPositions(for: d4).isEmpty)
    }

    @Test("Notes on the staff need no ledger lines") func noLedgerOnStaff() {
        let geo = StaffGeometry(clefType: .treble)
        let g4 = Pitch(step: .g, octave: 4)
        #expect(geo.ledgerLineYPositions(for: g4).isEmpty)
    }

    @Test("A5 needs one ledger line above treble clef") func a5LedgerAbove() {
        let geo = StaffGeometry(clefType: .treble)
        let a5 = Pitch(step: .a, octave: 5)
        let ledgers = geo.ledgerLineYPositions(for: a5)
        #expect(ledgers.count == 1)
    }

    @Test("Stem up for notes below middle line") func stemUpBelow() {
        let geo = StaffGeometry(clefType: .treble)
        let a4 = Pitch(step: .a, octave: 4)
        #expect(geo.stemUp(for: a4) == true)
    }

    @Test("Stem down for notes at middle line") func stemDownMiddle() {
        let geo = StaffGeometry(clefType: .treble)
        let b4 = Pitch(step: .b, octave: 4)
        #expect(geo.stemUp(for: b4) == false)
    }

    @Test("Stem down for notes above middle line") func stemDownAbove() {
        let geo = StaffGeometry(clefType: .treble)
        let d5 = Pitch(step: .d, octave: 5)
        #expect(geo.stemUp(for: d5) == false)
    }

    @Test("Staff line Y positions are evenly spaced") func lineYSpacing() {
        let geo = StaffGeometry(staffSpacing: 8.0, clefType: .treble)
        #expect(geo.lineY(0) == 0)
        #expect(geo.lineY(1) == 8)
        #expect(geo.lineY(2) == 16)
        #expect(geo.lineY(3) == 24)
        #expect(geo.lineY(4) == 32)
    }

    @Test("Bass part types use bass clef") func bassClef() {
        #expect(PartType.bass.clefType == .bass)
        #expect(PartType.bass1.clefType == .bass)
        #expect(PartType.bass2.clefType == .bass)
    }

    @Test("Non-bass part types use treble clef") func trebleClef() {
        #expect(PartType.soprano.clefType == .treble)
        #expect(PartType.alto.clefType == .treble)
        #expect(PartType.tenor.clefType == .treble)
        #expect(PartType.piano.clefType == .treble)
    }

    // MARK: - Key Signature Positions

    @Test("C major (0 fifths) returns empty positions") func keySigCMajor() {
        let geo = StaffGeometry(clefType: .treble)
        #expect(geo.keySignaturePositions(fifths: 0).isEmpty)
    }

    @Test("G major (1 sharp) returns F5 position in treble clef") func keySigGMajor() {
        let geo = StaffGeometry(clefType: .treble)
        let positions = geo.keySignaturePositions(fifths: 1)
        #expect(positions.count == 1)
        #expect(positions[0] == 38)  // F5
    }

    @Test("D major (2 sharps) returns F5 and C5 in treble clef") func keySigDMajor() {
        let geo = StaffGeometry(clefType: .treble)
        let positions = geo.keySignaturePositions(fifths: 2)
        #expect(positions.count == 2)
        #expect(positions == [38, 35])  // F5, C5
    }

    @Test("Bb major (2 flats) returns B4 and E5 in treble clef") func keySigBbMajor() {
        let geo = StaffGeometry(clefType: .treble)
        let positions = geo.keySignaturePositions(fifths: -2)
        #expect(positions.count == 2)
        #expect(positions == [34, 37])  // B4, E5
    }

    @Test("Bass clef sharp positions differ from treble") func keySigBassClef() {
        let geo = StaffGeometry(clefType: .bass)
        let positions = geo.keySignaturePositions(fifths: 1)
        #expect(positions.count == 1)
        #expect(positions[0] == 24)  // F3
    }
}
