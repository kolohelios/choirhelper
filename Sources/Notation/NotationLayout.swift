import CoreGraphics
import Models

/// A positioned note ready for rendering.
public struct LayoutNote: Sendable {
    /// X position of the notehead center.
    public let x: CGFloat
    /// Y positions of each notehead center relative to the staff top line.
    public let ys: [CGFloat]
    /// The note type (whole, half, quarter, etc.).
    public let noteType: NoteType
    /// Whether this note is a rest.
    public let isRest: Bool
    /// Whether the stem points up.
    public let stemUp: Bool
    /// Accidentals to display per pitch (-1 flat, 0 none, 1 sharp).
    public let accidentals: [Int]
    /// Lyric syllable text, if any.
    public let lyricText: String?
    /// Y positions for ledger lines needed by this note.
    public let ledgerLineYs: [CGFloat]
    /// Beat position in the piece (for cursor tracking).
    public let beatPosition: Double

    /// Backward-compatible single Y position (first pitch).
    public var y: CGFloat { ys.first ?? 0 }
    /// Backward-compatible single accidental (first pitch).
    public var accidental: Int { accidentals.first ?? 0 }
    /// Whether this layout note represents a chord.
    public var isChord: Bool { ys.count > 1 }

    public init(
        x: CGFloat, ys: [CGFloat], noteType: NoteType, isRest: Bool, stemUp: Bool,
        accidentals: [Int], lyricText: String?, ledgerLineYs: [CGFloat], beatPosition: Double
    ) {
        self.x = x
        self.ys = ys
        self.noteType = noteType
        self.isRest = isRest
        self.stemUp = stemUp
        self.accidentals = accidentals
        self.lyricText = lyricText
        self.ledgerLineYs = ledgerLineYs
        self.beatPosition = beatPosition
    }

    public init(
        x: CGFloat, y: CGFloat, noteType: NoteType, isRest: Bool, stemUp: Bool, accidental: Int,
        lyricText: String?, ledgerLineYs: [CGFloat], beatPosition: Double
    ) {
        self.x = x
        self.ys = [y]
        self.noteType = noteType
        self.isRest = isRest
        self.stemUp = stemUp
        self.accidentals = [accidental]
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

    /// Reverse lookup: X position to beat position.
    /// Returns the beat position corresponding to the given X coordinate,
    /// or nil if X is outside this line's bounds.
    public func beatPosition(forX x: CGFloat) -> Double? {
        // Find the measure containing this X
        guard let measure = measures.first(where: { x >= $0.x && x < $0.x + $0.width }) else {
            return nil
        }

        // Find the note interval containing X
        for (index, note) in measure.notes.enumerated() {
            let nextX: CGFloat
            let noteEnd: Double
            if index + 1 < measure.notes.count {
                nextX = measure.notes[index + 1].x
                noteEnd = measure.notes[index + 1].beatPosition
            } else {
                nextX = measure.x + measure.width - StaffGeometry.measurePadding
                noteEnd =
                    measure.startBeat
                    + measure.notes.reduce(0) { sum, nt in sum + nt.noteType.relativeDuration }
            }

            if x >= note.x && x < nextX {
                let fraction =
                    nextX > note.x ? Double((x - note.x) / (nextX - note.x)) : 0
                return note.beatPosition + fraction * (noteEnd - note.beatPosition)
            }
        }

        // Before first note in measure — snap to measure start
        return measure.startBeat
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
