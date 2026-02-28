import CoreGraphics
import Models

/// Constants and calculations for mapping pitches to staff positions.
public struct StaffGeometry: Sendable {
    /// Distance between adjacent staff lines in points.
    public let staffSpacing: CGFloat

    /// The clef type determining pitch-to-line mapping.
    public let clefType: ClefType

    /// Octave shift applied to display positions (e.g. +1 for tenor octave treble clef).
    public let octaveTransposition: Int

    /// Minimum horizontal spacing between notes in points.
    public static let minNoteSpacing: CGFloat = 20.0

    /// Base width multiplied by note duration to get horizontal spacing.
    public static let baseNoteWidth: CGFloat = 40.0

    /// Width reserved for the clef symbol at the start of a line.
    public static let clefWidth: CGFloat = 32.0

    /// Width reserved for the key signature after the clef.
    public static let keySignatureWidth: CGFloat = 24.0

    /// Width reserved for the time signature after the key signature.
    public static let timeSignatureWidth: CGFloat = 24.0

    /// Padding at the start and end of each measure.
    public static let measurePadding: CGFloat = 8.0

    public init(staffSpacing: CGFloat = 8.0, clefType: ClefType = .treble, octaveTransposition: Int = 0) {
        self.staffSpacing = staffSpacing
        self.clefType = clefType
        self.octaveTransposition = octaveTransposition
    }

    /// Total height of the 5-line staff (4 spaces between 5 lines).
    public var staffHeight: CGFloat { staffSpacing * 4.0 }

    /// Diatonic index of the top staff line.
    public var topLineDiatonicIndex: Int {
        switch clefType {
        case .treble: 38  // F5
        case .bass: 26  // A3
        }
    }

    /// Diatonic index of the bottom staff line.
    public var bottomLineDiatonicIndex: Int { topLineDiatonicIndex - 8 }

    /// Diatonic index of the middle staff line (used for stem direction).
    public var middleLineDiatonicIndex: Int { topLineDiatonicIndex - 4 }

    /// Returns the diatonic index for a pitch. C0 = 0, D0 = 1, ... C4 = 28, etc.
    public static func diatonicIndex(for pitch: Pitch) -> Int {
        let stepIndex: Int
        switch pitch.step {
        case .c: stepIndex = 0
        case .d: stepIndex = 1
        case .e: stepIndex = 2
        case .f: stepIndex = 3
        case .g: stepIndex = 4
        case .a: stepIndex = 5
        case .b: stepIndex = 6
        }
        return pitch.octave * 7 + stepIndex
    }

    /// Diatonic index adjusted for octave transposition (e.g. tenor display).
    public func displayDiatonicIndex(for pitch: Pitch) -> Int {
        Self.diatonicIndex(for: pitch) + octaveTransposition * 7
    }

    /// Y position of a pitch relative to the top of the staff.
    /// Top line = 0, each diatonic step down adds staffSpacing/2.
    public func yPosition(for pitch: Pitch) -> CGFloat {
        yPosition(forDiatonicIndex: displayDiatonicIndex(for: pitch))
    }

    /// Y position for a diatonic index relative to the top of the staff.
    public func yPosition(forDiatonicIndex index: Int) -> CGFloat {
        CGFloat(topLineDiatonicIndex - index) * staffSpacing / 2.0
    }

    /// Y positions where ledger lines should be drawn for a pitch outside the staff.
    public func ledgerLineYPositions(for pitch: Pitch) -> [CGFloat] {
        let noteIndex = displayDiatonicIndex(for: pitch)
        var positions: [CGFloat] = []

        if noteIndex > topLineDiatonicIndex {
            let count = (noteIndex - topLineDiatonicIndex) / 2
            if count > 0 {
                for i in 1...count {
                    positions.append(yPosition(forDiatonicIndex: topLineDiatonicIndex + i * 2))
                }
            }
        } else if noteIndex < bottomLineDiatonicIndex {
            let count = (bottomLineDiatonicIndex - noteIndex) / 2
            if count > 0 {
                for i in 1...count {
                    positions.append(yPosition(forDiatonicIndex: bottomLineDiatonicIndex - i * 2))
                }
            }
        }

        return positions
    }

    /// Whether the stem should point up for a given pitch.
    /// Notes below the middle line get stems up; at or above get stems down.
    public func stemUp(for pitch: Pitch) -> Bool {
        displayDiatonicIndex(for: pitch) < middleLineDiatonicIndex
    }

    /// Y position of a staff line by index (0 = top line, 4 = bottom line).
    public func lineY(_ lineIndex: Int) -> CGFloat { CGFloat(lineIndex) * staffSpacing }

    /// Diatonic indices for key signature accidentals on this clef.
    /// Returns an array of length `abs(fifths)` giving the staff position
    /// for each sharp (fifths > 0) or flat (fifths < 0).
    public func keySignaturePositions(fifths: Int) -> [Int] {
        guard fifths != 0 else { return [] }

        // Standard positions per clef. Each accidental is placed to stay
        // within the staff, following the traditional zigzag pattern.
        let trebleSharps = [38, 35, 32, 36, 33, 37, 34]  // F5 C5 G4 D5 A4 E5 B4
        let trebleFlats  = [34, 37, 33, 36, 32, 35, 31]   // B4 E5 A4 D5 G4 C5 F4
        let bassSharps   = [24, 21, 25, 22, 19, 23, 20]   // F3 C3 G3 D3 A2 E3 B2
        let bassFlats    = [20, 23, 19, 22, 18, 21, 24]   // B2 E3 A2 D3 G2 C3 F3

        let positions: [Int]
        switch (clefType, fifths > 0) {
        case (.treble, true):  positions = trebleSharps
        case (.treble, false): positions = trebleFlats
        case (.bass, true):    positions = bassSharps
        case (.bass, false):   positions = bassFlats
        }

        return Array(positions.prefix(abs(fifths)))
    }
}
