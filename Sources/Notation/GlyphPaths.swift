import CoreGraphics
import Models

/// CGPath factories for drawing music notation symbols on a Canvas.
public enum GlyphPaths: Sendable {
    // MARK: - Noteheads

    /// Filled notehead (quarter, eighth, sixteenth).
    public static func filledNotehead(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let width = spacing * 1.3
        let height = spacing * 0.9
        return ovalPath(center: center, width: width, height: height)
    }

    /// Hollow notehead (half note).
    public static func hollowNotehead(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let width = spacing * 1.3
        let height = spacing * 0.9
        return ovalPath(center: center, width: width, height: height)
    }

    /// Whole notehead (wider, hollow).
    public static func wholeNotehead(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let width = spacing * 1.5
        let height = spacing * 0.9
        return ovalPath(center: center, width: width, height: height)
    }

    /// Returns whether a note type uses a filled notehead.
    public static func isFilled(_ noteType: NoteType) -> Bool {
        switch noteType {
        case .whole, .half: false
        case .quarter, .eighth, .sixteenth: true
        }
    }

    // MARK: - Stems

    /// Stem line from a notehead. Returns (start, end) points.
    public static func stemEndpoints(
        noteCenter: CGPoint, stemUp: Bool, spacing: CGFloat
    ) -> (start: CGPoint, end: CGPoint) {
        let stemLength = spacing * 3.5
        let noteRadius = spacing * 0.65
        if stemUp {
            let start = CGPoint(x: noteCenter.x + noteRadius, y: noteCenter.y)
            let end = CGPoint(x: start.x, y: noteCenter.y - stemLength)
            return (start, end)
        } else {
            let start = CGPoint(x: noteCenter.x - noteRadius, y: noteCenter.y)
            let end = CGPoint(x: start.x, y: noteCenter.y + stemLength)
            return (start, end)
        }
    }

    /// Path for a note stem.
    public static func stemPath(noteCenter: CGPoint, stemUp: Bool, spacing: CGFloat) -> CGPath {
        let endpoints = stemEndpoints(noteCenter: noteCenter, stemUp: stemUp, spacing: spacing)
        let path = CGMutablePath()
        path.move(to: endpoints.start)
        path.addLine(to: endpoints.end)
        return path
    }

    // MARK: - Flags

    /// Single flag path (for eighth notes).
    public static func flagPath(noteCenter: CGPoint, stemUp: Bool, spacing: CGFloat) -> CGPath {
        let endpoints = stemEndpoints(noteCenter: noteCenter, stemUp: stemUp, spacing: spacing)
        let stemEnd = endpoints.end
        let flagLength = spacing * 2.0
        let path = CGMutablePath()

        if stemUp {
            path.move(to: stemEnd)
            path.addCurve(
                to: CGPoint(x: stemEnd.x + spacing, y: stemEnd.y + flagLength),
                control1: CGPoint(x: stemEnd.x + spacing * 1.2, y: stemEnd.y + spacing * 0.3),
                control2: CGPoint(x: stemEnd.x + spacing * 1.5, y: stemEnd.y + flagLength * 0.6))
        } else {
            path.move(to: stemEnd)
            path.addCurve(
                to: CGPoint(x: stemEnd.x - spacing, y: stemEnd.y - flagLength),
                control1: CGPoint(x: stemEnd.x - spacing * 1.2, y: stemEnd.y - spacing * 0.3),
                control2: CGPoint(x: stemEnd.x - spacing * 1.5, y: stemEnd.y - flagLength * 0.6))
        }

        return path
    }

    /// Double flag path (for sixteenth notes).
    public static func doubleFlagPath(noteCenter: CGPoint, stemUp: Bool, spacing: CGFloat) -> CGPath
    {
        let endpoints = stemEndpoints(noteCenter: noteCenter, stemUp: stemUp, spacing: spacing)
        let stemEnd = endpoints.end
        let flagLength = spacing * 1.6
        let flagGap = spacing * 0.8
        let path = CGMutablePath()

        if stemUp {
            for offset in [0.0, flagGap] {
                let start = CGPoint(x: stemEnd.x, y: stemEnd.y + offset)
                path.move(to: start)
                path.addCurve(
                    to: CGPoint(x: start.x + spacing, y: start.y + flagLength),
                    control1: CGPoint(x: start.x + spacing * 1.2, y: start.y + spacing * 0.3),
                    control2: CGPoint(x: start.x + spacing * 1.5, y: start.y + flagLength * 0.6))
            }
        } else {
            for offset in [0.0, -flagGap] {
                let start = CGPoint(x: stemEnd.x, y: stemEnd.y + offset)
                path.move(to: start)
                path.addCurve(
                    to: CGPoint(x: start.x - spacing, y: start.y - flagLength),
                    control1: CGPoint(x: start.x - spacing * 1.2, y: start.y - spacing * 0.3),
                    control2: CGPoint(x: start.x - spacing * 1.5, y: start.y - flagLength * 0.6))
            }
        }

        return path
    }

    // MARK: - Rests

    /// Bounding rect for a rest symbol centered at a point.
    public static func restBounds(
        at center: CGPoint, noteType: NoteType, spacing: CGFloat
    ) -> CGRect {
        let width: CGFloat
        let height: CGFloat
        switch noteType {
        case .whole:
            width = spacing * 1.5
            height = spacing * 0.5
        case .half:
            width = spacing * 1.5
            height = spacing * 0.5
        case .quarter:
            width = spacing * 0.8
            height = spacing * 3.0
        case .eighth:
            width = spacing * 1.0
            height = spacing * 2.0
        case .sixteenth:
            width = spacing * 1.0
            height = spacing * 2.5
        }
        return CGRect(
            x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    /// Path for a whole rest (filled rectangle hanging from a line).
    public static func wholeRestPath(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let width = spacing * 1.5
        let height = spacing * 0.5
        return CGPath(
            rect: CGRect(x: center.x - width / 2, y: center.y, width: width, height: height),
            transform: nil)
    }

    /// Path for a half rest (filled rectangle sitting on a line).
    public static func halfRestPath(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let width = spacing * 1.5
        let height = spacing * 0.5
        return CGPath(
            rect: CGRect(
                x: center.x - width / 2, y: center.y - height, width: width, height: height),
            transform: nil)
    }

    /// Simplified quarter rest path (zigzag shape).
    public static func quarterRestPath(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let top = CGPoint(x: center.x, y: center.y - spacing * 1.5)

        path.move(to: top)
        path.addLine(to: CGPoint(x: center.x + spacing * 0.4, y: center.y - spacing * 0.8))
        path.addLine(to: CGPoint(x: center.x - spacing * 0.3, y: center.y - spacing * 0.2))
        path.addLine(to: CGPoint(x: center.x + spacing * 0.3, y: center.y + spacing * 0.4))
        path.addCurve(
            to: CGPoint(x: center.x - spacing * 0.2, y: center.y + spacing * 1.5),
            control1: CGPoint(x: center.x + spacing * 0.4, y: center.y + spacing * 0.8),
            control2: CGPoint(x: center.x, y: center.y + spacing * 1.2))

        return path
    }

    // MARK: - Accidentals

    /// X offset for an accidental glyph (placed to the left of the notehead).
    public static func accidentalXOffset(spacing: CGFloat) -> CGFloat { spacing * 1.5 }

    /// Path for a sharp sign.
    public static func sharpPath(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let halfHeight = spacing * 1.2
        let halfWidth = spacing * 0.35
        let lineGap = spacing * 0.35

        // Two vertical lines
        path.move(to: CGPoint(x: center.x - lineGap, y: center.y - halfHeight))
        path.addLine(to: CGPoint(x: center.x - lineGap, y: center.y + halfHeight))
        path.move(to: CGPoint(x: center.x + lineGap, y: center.y - halfHeight))
        path.addLine(to: CGPoint(x: center.x + lineGap, y: center.y + halfHeight))

        // Two horizontal bars (slightly angled)
        path.move(to: CGPoint(x: center.x - halfWidth, y: center.y - lineGap + spacing * 0.1))
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y - lineGap - spacing * 0.1))
        path.move(to: CGPoint(x: center.x - halfWidth, y: center.y + lineGap + spacing * 0.1))
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y + lineGap - spacing * 0.1))

        return path
    }

    /// Path for a flat sign.
    public static func flatPath(at center: CGPoint, spacing: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let top = CGPoint(x: center.x - spacing * 0.15, y: center.y - spacing * 1.5)

        // Vertical stem
        path.move(to: top)
        path.addLine(to: CGPoint(x: top.x, y: center.y + spacing * 0.5))

        // Curved belly
        path.move(to: CGPoint(x: top.x, y: center.y - spacing * 0.1))
        path.addCurve(
            to: CGPoint(x: top.x, y: center.y + spacing * 0.5),
            control1: CGPoint(x: top.x + spacing * 0.8, y: center.y - spacing * 0.3),
            control2: CGPoint(x: top.x + spacing * 0.6, y: center.y + spacing * 0.5))

        return path
    }

    // MARK: - Barlines

    /// Path for a single barline.
    public static func barlinePath(x: CGFloat, staffTop: CGFloat, staffHeight: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: staffTop))
        path.addLine(to: CGPoint(x: x, y: staffTop + staffHeight))
        return path
    }

    /// Path for a ledger line.
    public static func ledgerLinePath(x: CGFloat, y: CGFloat, spacing: CGFloat) -> CGPath {
        let halfWidth = spacing * 1.0
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x - halfWidth, y: y))
        path.addLine(to: CGPoint(x: x + halfWidth, y: y))
        return path
    }

    // MARK: - Helpers

    private static func ovalPath(center: CGPoint, width: CGFloat, height: CGFloat) -> CGPath {
        CGPath(
            ellipseIn: CGRect(
                x: center.x - width / 2, y: center.y - height / 2, width: width, height: height),
            transform: nil)
    }
}
