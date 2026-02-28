import Models
import SwiftUI

/// Draws a single line of music notation using SwiftUI Canvas.
public struct NotationCanvasView: View {
    let line: LayoutLine
    let staffGeometry: StaffGeometry
    let keySignature: KeySignature
    let timeSignature: TimeSignature?
    let currentBeat: Double?
    let showLyrics: Bool
    let showMeasureNumbers: Bool

    public init(
        line: LayoutLine, staffGeometry: StaffGeometry, keySignature: KeySignature = KeySignature(fifths: 0),
        timeSignature: TimeSignature? = nil,
        currentBeat: Double? = nil, showLyrics: Bool = true, showMeasureNumbers: Bool = true
    ) {
        self.line = line
        self.staffGeometry = staffGeometry
        self.keySignature = keySignature
        self.timeSignature = timeSignature
        self.currentBeat = currentBeat
        self.showLyrics = showLyrics
        self.showMeasureNumbers = showMeasureNumbers
    }

    private var staffTop: CGFloat { staffGeometry.staffSpacing * 2 }
    private var lyricAreaHeight: CGFloat { showLyrics ? staffGeometry.staffSpacing * 3 : 0 }

    private var totalHeight: CGFloat {
        staffTop + staffGeometry.staffHeight + staffGeometry.staffSpacing * 4 + lyricAreaHeight
    }

    public var body: some View {
        Canvas { context, size in
            let staffY = staffTop

            drawStaffLines(context: context, staffY: staffY, width: size.width)
            drawClef(context: context, staffY: staffY)
            drawKeySignature(context: context, staffY: staffY)
            drawTimeSignature(context: context, staffY: staffY)

            for measure in line.measures {
                drawBarline(context: context, x: measure.x, staffY: staffY)

                if showMeasureNumbers {
                    drawMeasureNumber(context: context, measure: measure, staffY: staffY)
                }

                for note in measure.notes {
                    drawNote(context: context, note: note, staffY: staffY)

                    if showLyrics, let lyricText = note.lyricText {
                        drawLyric(context: context, text: lyricText, noteX: note.x, staffY: staffY)
                    }
                }
            }

            // Trailing barline
            if let lastMeasure = line.measures.last {
                let trailingX = lastMeasure.x + lastMeasure.width
                drawBarline(context: context, x: trailingX, staffY: staffY)
            }

            if let beat = currentBeat, beat >= line.startBeat, beat < line.endBeat {
                drawCursor(context: context, beat: beat, staffY: staffY)
            }
        }.frame(height: totalHeight)
    }

    // MARK: - Drawing Methods

    private func drawStaffLines(context: GraphicsContext, staffY: CGFloat, width: CGFloat) {
        for lineIdx in 0..<5 {
            let y = staffY + staffGeometry.lineY(lineIdx)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
            context.stroke(path, with: .color(.primary.opacity(0.6)), lineWidth: 1)
        }
    }

    private func drawClef(context: GraphicsContext, staffY: CGFloat) {
        let clefText: String
        let fontSize: CGFloat
        let yOffset: CGFloat

        switch staffGeometry.clefType {
        case .treble:
            clefText = "\u{1D11E}"  // 𝄞
            fontSize = staffGeometry.staffSpacing * 5.5
            yOffset = staffGeometry.staffSpacing * 0.5
        case .bass:
            clefText = "\u{1D122}"  // 𝄢
            fontSize = staffGeometry.staffSpacing * 3.5
            yOffset = staffGeometry.staffSpacing * 0.3
        }

        let resolved = context.resolve(Text(clefText).font(.system(size: fontSize)))
        context.draw(
            resolved, at: CGPoint(x: StaffGeometry.clefWidth / 2, y: staffY + yOffset), anchor: .top
        )
    }

    private func drawKeySignature(context: GraphicsContext, staffY: CGFloat) {
        let fifths = keySignature.fifths
        guard fifths != 0 else { return }

        let spacing = staffGeometry.staffSpacing
        let accidentalCount = abs(fifths)
        let positions = staffGeometry.keySignaturePositions(fifths: fifths)
        let startX = StaffGeometry.clefWidth + spacing * 0.5
        let step = min(spacing * 1.2, (StaffGeometry.keySignatureWidth - spacing) / CGFloat(accidentalCount))

        for (index, diatonicIndex) in positions.enumerated() {
            let x = startX + CGFloat(index) * step
            let y = staffY + staffGeometry.yPosition(forDiatonicIndex: diatonicIndex)
            let center = CGPoint(x: x, y: y)

            let path: CGPath
            if fifths > 0 {
                path = GlyphPaths.sharpPath(at: center, spacing: spacing)
            } else {
                path = GlyphPaths.flatPath(at: center, spacing: spacing)
            }
            context.stroke(Path(path), with: .color(.primary), lineWidth: 1.2)
        }
    }

    private func drawTimeSignature(context: GraphicsContext, staffY: CGFloat) {
        guard let ts = timeSignature else { return }

        // Only draw when the layout reserved space for it (first line).
        let sigThreshold = StaffGeometry.clefWidth + StaffGeometry.keySignatureWidth
            + StaffGeometry.timeSignatureWidth
        guard let firstMeasureX = line.measures.first?.x, firstMeasureX >= sigThreshold - 1 else {
            return
        }

        let spacing = staffGeometry.staffSpacing
        let centerX = StaffGeometry.clefWidth + StaffGeometry.keySignatureWidth
            + StaffGeometry.timeSignatureWidth / 2
        let fontSize = spacing * 2.8

        // Top number (beats) centered on upper half of staff
        let topY = staffY + spacing  // Between lines 1 and 2
        let topResolved = context.resolve(
            Text("\(ts.beats)").font(.system(size: fontSize, weight: .bold, design: .serif)))
        context.draw(topResolved, at: CGPoint(x: centerX, y: topY), anchor: .center)

        // Bottom number (beat type) centered on lower half of staff
        let bottomY = staffY + spacing * 3  // Between lines 3 and 4
        let bottomResolved = context.resolve(
            Text("\(ts.beatType)").font(.system(size: fontSize, weight: .bold, design: .serif)))
        context.draw(bottomResolved, at: CGPoint(x: centerX, y: bottomY), anchor: .center)
    }

    private func drawBarline(context: GraphicsContext, x: CGFloat, staffY: CGFloat) {
        let barline = GlyphPaths.barlinePath(
            x: x, staffTop: staffY, staffHeight: staffGeometry.staffHeight)
        context.stroke(Path(barline), with: .color(.primary.opacity(0.5)), lineWidth: 1)
    }

    private func drawMeasureNumber(
        context: GraphicsContext, measure: LayoutMeasure, staffY: CGFloat
    ) {
        let resolved = context.resolve(
            Text("\(measure.number)").font(.system(size: staffGeometry.staffSpacing * 0.9))
                .foregroundStyle(.secondary))
        context.draw(
            resolved, at: CGPoint(x: measure.x + 4, y: staffY - staffGeometry.staffSpacing * 0.5),
            anchor: .bottomLeading)
    }

    private func drawNote(context: GraphicsContext, note: LayoutNote, staffY: CGFloat) {
        let spacing = staffGeometry.staffSpacing

        if note.isRest {
            let center = CGPoint(x: note.x, y: staffY + note.y)
            drawRest(context: context, note: note, center: center, spacing: spacing)
            return
        }

        // Ledger lines
        for ledgerY in note.ledgerLineYs {
            let ledgerPath = GlyphPaths.ledgerLinePath(
                x: note.x, y: staffY + ledgerY, spacing: spacing)
            context.stroke(Path(ledgerPath), with: .color(.primary.opacity(0.6)), lineWidth: 1)
        }

        // Draw each notehead and its accidental
        for (index, noteY) in note.ys.enumerated() {
            let center = CGPoint(x: note.x, y: staffY + noteY)

            // Accidental for this pitch
            if index < note.accidentals.count, note.accidentals[index] != 0 {
                let accidentalX = center.x - GlyphPaths.accidentalXOffset(spacing: spacing)
                let accidentalCenter = CGPoint(x: accidentalX, y: center.y)
                let path: CGPath
                if note.accidentals[index] > 0 {
                    path = GlyphPaths.sharpPath(at: accidentalCenter, spacing: spacing)
                } else {
                    path = GlyphPaths.flatPath(at: accidentalCenter, spacing: spacing)
                }
                context.stroke(Path(path), with: .color(.primary), lineWidth: 1.2)
            }

            // Notehead
            drawNotehead(context: context, note: note, center: center, spacing: spacing)
        }

        // Stem (not for whole notes) — spans from outermost notehead to stem end
        if note.noteType != .whole {
            let stemNoteheadY: CGFloat
            if note.stemUp {
                // Stem goes up from the lowest (highest Y value) notehead
                stemNoteheadY = note.ys.max() ?? note.y
            } else {
                // Stem goes down from the highest (lowest Y value) notehead
                stemNoteheadY = note.ys.min() ?? note.y
            }
            let stemCenter = CGPoint(x: note.x, y: staffY + stemNoteheadY)
            let stemPath = GlyphPaths.stemPath(
                noteCenter: stemCenter, stemUp: note.stemUp, spacing: spacing)
            context.stroke(Path(stemPath), with: .color(.primary), lineWidth: 1.2)

            // Flags at stem tip
            drawFlags(context: context, note: note, center: stemCenter, spacing: spacing)
        }
    }

    private func drawNotehead(
        context: GraphicsContext, note: LayoutNote, center: CGPoint, spacing: CGFloat
    ) {
        let headPath: CGPath
        let isFilled: Bool

        switch note.noteType {
        case .whole:
            headPath = GlyphPaths.wholeNotehead(at: center, spacing: spacing)
            isFilled = false
        case .half:
            headPath = GlyphPaths.hollowNotehead(at: center, spacing: spacing)
            isFilled = false
        case .quarter, .eighth, .sixteenth:
            headPath = GlyphPaths.filledNotehead(at: center, spacing: spacing)
            isFilled = true
        }

        if isFilled {
            context.fill(Path(headPath), with: .color(.primary))
        } else {
            context.stroke(Path(headPath), with: .color(.primary), lineWidth: 1.5)
        }
    }

    private func drawFlags(
        context: GraphicsContext, note: LayoutNote, center: CGPoint, spacing: CGFloat
    ) {
        switch note.noteType {
        case .eighth:
            let flagPath = GlyphPaths.flagPath(
                noteCenter: center, stemUp: note.stemUp, spacing: spacing)
            context.stroke(Path(flagPath), with: .color(.primary), lineWidth: 1.5)
        case .sixteenth:
            let flagPath = GlyphPaths.doubleFlagPath(
                noteCenter: center, stemUp: note.stemUp, spacing: spacing)
            context.stroke(Path(flagPath), with: .color(.primary), lineWidth: 1.5)
        default: break
        }
    }

    private func drawRest(
        context: GraphicsContext, note: LayoutNote, center: CGPoint, spacing: CGFloat
    ) {
        switch note.noteType {
        case .whole:
            let path = GlyphPaths.wholeRestPath(at: center, spacing: spacing)
            context.fill(Path(path), with: .color(.primary))
        case .half:
            let path = GlyphPaths.halfRestPath(at: center, spacing: spacing)
            context.fill(Path(path), with: .color(.primary))
        case .quarter:
            let path = GlyphPaths.quarterRestPath(at: center, spacing: spacing)
            context.stroke(Path(path), with: .color(.primary), lineWidth: 1.5)
        case .eighth, .sixteenth:
            let resolved = context.resolve(Text("\u{1D13D}").font(.system(size: spacing * 2.5)))
            context.draw(resolved, at: center, anchor: .center)
        }
    }

    private func drawLyric(context: GraphicsContext, text: String, noteX: CGFloat, staffY: CGFloat)
    {
        let lyricY = staffY + staffGeometry.staffHeight + staffGeometry.staffSpacing * 3
        let resolved = context.resolve(
            Text(text).font(.system(size: staffGeometry.staffSpacing * 1.2)).foregroundStyle(
                .primary))
        context.draw(resolved, at: CGPoint(x: noteX, y: lyricY), anchor: .top)
    }

    private func drawCursor(context: GraphicsContext, beat: Double, staffY: CGFloat) {
        // Find the X position for the current beat via interpolation
        guard let cursorX = xPosition(forBeat: beat) else { return }

        var path = Path()
        let cursorTop = staffY - staffGeometry.staffSpacing
        let cursorBottom = staffY + staffGeometry.staffHeight + staffGeometry.staffSpacing
        path.move(to: CGPoint(x: cursorX, y: cursorTop))
        path.addLine(to: CGPoint(x: cursorX, y: cursorBottom))
        context.stroke(path, with: .color(.accentColor.opacity(0.7)), lineWidth: 2.5)
    }

    private func xPosition(forBeat beat: Double) -> CGFloat? {
        // Search through notes to find position
        for measure in line.measures {
            for (index, note) in measure.notes.enumerated() {
                let noteEnd: Double
                if index + 1 < measure.notes.count {
                    noteEnd = measure.notes[index + 1].beatPosition
                } else {
                    noteEnd =
                        measure.startBeat
                        + measure.notes.reduce(0) { sum, nt in sum + nt.noteType.relativeDuration }
                }

                if beat >= note.beatPosition && beat < noteEnd {
                    // Interpolate within this note
                    let fraction =
                        noteEnd > note.beatPosition
                        ? (beat - note.beatPosition) / (noteEnd - note.beatPosition) : 0
                    let nextX: CGFloat
                    if index + 1 < measure.notes.count {
                        nextX = measure.notes[index + 1].x
                    } else {
                        nextX = measure.x + measure.width - StaffGeometry.measurePadding
                    }
                    return note.x + CGFloat(fraction) * (nextX - note.x)
                }
            }
        }

        // Fallback: position at start of first note
        return line.measures.first?.notes.first?.x
    }
}
