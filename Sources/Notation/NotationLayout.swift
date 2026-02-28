import CoreGraphics
import Models

/// A positioned note ready for rendering.
public struct LayoutNote: Sendable {
    /// X position of the notehead center.
    public let x: CGFloat
    /// Y position of the notehead center relative to the staff top line.
    public let y: CGFloat
    /// The note type (whole, half, quarter, etc.).
    public let noteType: NoteType
    /// Whether this note is a rest.
    public let isRest: Bool
    /// Whether the stem points up.
    public let stemUp: Bool
    /// Accidental to display (-1 flat, 0 none, 1 sharp).
    public let accidental: Int
    /// Lyric syllable text, if any.
    public let lyricText: String?
    /// Y positions for ledger lines needed by this note.
    public let ledgerLineYs: [CGFloat]
    /// Beat position in the piece (for cursor tracking).
    public let beatPosition: Double

    public init(
        x: CGFloat, y: CGFloat, noteType: NoteType, isRest: Bool, stemUp: Bool, accidental: Int,
        lyricText: String?, ledgerLineYs: [CGFloat], beatPosition: Double
    ) {
        self.x = x
        self.y = y
        self.noteType = noteType
        self.isRest = isRest
        self.stemUp = stemUp
        self.accidental = accidental
        self.lyricText = lyricText
        self.ledgerLineYs = ledgerLineYs
        self.beatPosition = beatPosition
    }
}

/// A positioned measure within a layout line.
public struct LayoutMeasure: Sendable {
    /// X position of the measure's leading barline.
    public let x: CGFloat
    /// Total width of this measure.
    public let width: CGFloat
    /// Measure number for display.
    public let number: Int
    /// Positioned notes within this measure.
    public let notes: [LayoutNote]
    /// Beat position where this measure starts.
    public let startBeat: Double

    public init(x: CGFloat, width: CGFloat, number: Int, notes: [LayoutNote], startBeat: Double) {
        self.x = x
        self.width = width
        self.number = number
        self.notes = notes
        self.startBeat = startBeat
    }
}

/// A single line of notation (one system).
public struct LayoutLine: Sendable {
    /// Measures on this line.
    public let measures: [LayoutMeasure]
    /// Beat position where this line starts.
    public let startBeat: Double
    /// Beat position where this line ends.
    public let endBeat: Double

    public init(measures: [LayoutMeasure], startBeat: Double, endBeat: Double) {
        self.measures = measures
        self.startBeat = startBeat
        self.endBeat = endBeat
    }
}

/// Complete layout result for a single part.
public struct NotationLayout: Sendable {
    /// Lines of notation, in order.
    public let lines: [LayoutLine]
    /// The staff geometry used for this layout.
    public let staffGeometry: StaffGeometry

    public init(lines: [LayoutLine], staffGeometry: StaffGeometry) {
        self.lines = lines
        self.staffGeometry = staffGeometry
    }

    /// Find the line index containing a given beat position.
    public func lineIndex(forBeat beat: Double) -> Int? {
        for (index, line) in lines.enumerated() where beat >= line.startBeat && beat < line.endBeat
        { return index }
        if let last = lines.last, beat >= last.endBeat { return lines.count - 1 }
        return nil
    }
}
