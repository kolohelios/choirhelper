import CoreGraphics
import Models

/// Constants and calculations for mapping pitches to staff positions.
public struct StaffGeometry: Sendable {
    /// Distance between adjacent staff lines in points.
    public let staffSpacing: CGFloat

    /// The clef type determining pitch-to-line mapping.
    public let clefType: ClefType

    /// Minimum horizontal spacing between notes in points.
    public static let minNoteSpacing: CGFloat = 20.0

    /// Base width multiplied by note duration to get horizontal spacing.
    public static let baseNoteWidth: CGFloat = 40.0

    /// Width reserved for the clef symbol at the start of a line.
    public static let clefWidth: CGFloat = 32.0

    /// Width reserved for key/time signature after clef.
    public static let signatureWidth: CGFloat = 24.0

    /// Padding at the start and end of each measure.
    public static let measurePadding: CGFloat = 8.0

    public init(staffSpacing: CGFloat = 8.0, clefType: ClefType = .treble) {
        self.staffSpacing = staffSpacing
        self.clefType = clefType
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

    /// Y position of a pitch relative to the top of the staff.
    /// Top line = 0, each diatonic step down adds staffSpacing/2.
    public func yPosition(for pitch: Pitch) -> CGFloat {
        yPosition(forDiatonicIndex: Self.diatonicIndex(for: pitch))
    }

    /// Y position for a diatonic index relative to the top of the staff.
    public func yPosition(forDiatonicIndex index: Int) -> CGFloat {
        CGFloat(topLineDiatonicIndex - index) * staffSpacing / 2.0
    }

    /// Y positions where ledger lines should be drawn for a pitch outside the staff.
    public func ledgerLineYPositions(for pitch: Pitch) -> [CGFloat] {
        let noteIndex = Self.diatonicIndex(for: pitch)
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
        Self.diatonicIndex(for: pitch) < middleLineDiatonicIndex
    }

    /// Y position of a staff line by index (0 = top line, 4 = bottom line).
    public func lineY(_ lineIndex: Int) -> CGFloat { CGFloat(lineIndex) * staffSpacing }
}
