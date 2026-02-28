import CoreGraphics
import Models

/// Converts a Part into a positioned NotationLayout for a given available width.
public struct NotationLayoutEngine: Sendable {
    private let staffGeometry: StaffGeometry
    private let availableWidth: CGFloat

    public init(staffGeometry: StaffGeometry, availableWidth: CGFloat) {
        self.staffGeometry = staffGeometry
        self.availableWidth = availableWidth
    }

    /// Lay out all measures of a part into lines that fit the available width.
    public func layout(part: Part) -> NotationLayout {
        let measures = part.measures
        guard !measures.isEmpty else {
            return NotationLayout(lines: [], staffGeometry: staffGeometry)
        }

        let measureWidths = measures.map { computeMinimumWidth(for: $0) }
        let lines = breakIntoLines(measures: measures, measureWidths: measureWidths)
        return NotationLayout(lines: lines, staffGeometry: staffGeometry)
    }

    /// Compute the minimum width needed for a measure based on its note durations.
    private func computeMinimumWidth(for measure: Measure) -> CGFloat {
        guard !measure.notes.isEmpty else {
            return StaffGeometry.measurePadding * 2 + StaffGeometry.minNoteSpacing
        }

        var width: CGFloat = StaffGeometry.measurePadding * 2
        for note in measure.notes {
            let noteWidth = max(
                StaffGeometry.minNoteSpacing,
                CGFloat(note.noteType.relativeDuration) * StaffGeometry.baseNoteWidth)
            width += noteWidth
        }
        return width
    }

    /// Break measures into lines using greedy line-filling, then justify each line.
    private func breakIntoLines(measures: [Measure], measureWidths: [CGFloat]) -> [LayoutLine] {
        var lines: [LayoutLine] = []
        var lineStart = 0
        var cumulativeBeat: Double = 0

        while lineStart < measures.count {
            let isFirstLine = lines.isEmpty
            let leadingWidth =
                isFirstLine
                ? StaffGeometry.clefWidth + StaffGeometry.keySignatureWidth
                    + StaffGeometry.timeSignatureWidth
                : StaffGeometry.clefWidth

            var usedWidth = leadingWidth
            var lineEnd = lineStart

            // Greedily pack measures into this line
            while lineEnd < measures.count {
                let mw = measureWidths[lineEnd]
                if usedWidth + mw > availableWidth && lineEnd > lineStart { break }
                usedWidth += mw
                lineEnd += 1
            }

            // If no measure fits (very narrow width), force at least one
            if lineEnd == lineStart { lineEnd = lineStart + 1 }

            let lineMeasures = Array(measures[lineStart..<lineEnd])
            let lineMeasureWidths = Array(measureWidths[lineStart..<lineEnd])

            let lineStartBeat = cumulativeBeat
            let line = layoutLine(
                measures: lineMeasures, minimumWidths: lineMeasureWidths,
                leadingWidth: leadingWidth, startBeat: lineStartBeat)

            cumulativeBeat = line.endBeat
            lines.append(line)
            lineStart = lineEnd
        }

        return lines
    }

    /// Lay out a single line of measures, distributing extra space proportionally.
    private func layoutLine(
        measures: [Measure], minimumWidths: [CGFloat], leadingWidth: CGFloat, startBeat: Double
    ) -> LayoutLine {
        let totalMinWidth = minimumWidths.reduce(0, +)
        let extraSpace = max(0, availableWidth - leadingWidth - totalMinWidth)
        let totalDuration = measures.reduce(0.0) { $0 + $1.totalDuration }

        var layoutMeasures: [LayoutMeasure] = []
        var x = leadingWidth
        var cumulativeBeat = startBeat

        for (index, measure) in measures.enumerated() {
            // Distribute extra space proportionally to measure duration
            let proportion = totalDuration > 0 ? CGFloat(measure.totalDuration / totalDuration) : 0
            let extraForMeasure = extraSpace * proportion
            let measureWidth = minimumWidths[index] + extraForMeasure

            let layoutNotes = layoutNotes(
                in: measure, measureX: x, measureWidth: measureWidth, startBeat: cumulativeBeat)

            layoutMeasures.append(
                LayoutMeasure(
                    x: x, width: measureWidth, number: measure.number, notes: layoutNotes,
                    startBeat: cumulativeBeat))

            x += measureWidth
            cumulativeBeat += measure.totalDuration
        }

        return LayoutLine(measures: layoutMeasures, startBeat: startBeat, endBeat: cumulativeBeat)
    }

    /// Position individual notes within a measure.
    private func layoutNotes(
        in measure: Measure, measureX: CGFloat, measureWidth: CGFloat, startBeat: Double
    ) -> [LayoutNote] {
        guard !measure.notes.isEmpty else { return [] }

        let contentWidth = measureWidth - StaffGeometry.measurePadding * 2
        let contentStart = measureX + StaffGeometry.measurePadding
        let totalDuration = measure.totalDuration

        var result: [LayoutNote] = []
        var elapsed: Double = 0

        for note in measure.notes {
            let fraction = totalDuration > 0 ? elapsed / totalDuration : 0
            let noteWidth =
                totalDuration > 0
                ? contentWidth * CGFloat(note.duration / totalDuration)
                : contentWidth / CGFloat(measure.notes.count)
            let noteX = contentStart + CGFloat(fraction) * contentWidth + noteWidth / 2

            result.append(layoutSingleNote(note, x: noteX, beatPosition: startBeat + elapsed))
            elapsed += note.duration
        }

        return result
    }

    /// Compute position and visual properties for a single note (or chord).
    private func layoutSingleNote(_ note: Note, x: CGFloat, beatPosition: Double) -> LayoutNote {
        if note.isRest || note.pitches.isEmpty {
            let restY = staffGeometry.staffHeight / 2
            return LayoutNote(
                x: x, y: restY, noteType: note.noteType, isRest: note.isRest, stemUp: false,
                accidental: 0, lyricText: note.lyric?.text, ledgerLineYs: [],
                beatPosition: beatPosition)
        }

        let ys = note.pitches.map { staffGeometry.yPosition(for: $0) }
        let accidentals = note.pitches.map(\.alter)

        // Merge ledger lines from all pitches, deduplicated
        var ledgerSet = Set<CGFloat>()
        for pitch in note.pitches {
            for ly in staffGeometry.ledgerLineYPositions(for: pitch) {
                ledgerSet.insert(ly)
            }
        }
        let ledgerLineYs = ledgerSet.sorted()

        // Stem direction: compare outermost pitches' distance from middle line
        let stemUp: Bool
        if note.pitches.count == 1 {
            stemUp = staffGeometry.stemUp(for: note.pitches[0])
        } else {
            let middleY = staffGeometry.yPosition(
                forDiatonicIndex: staffGeometry.middleLineDiatonicIndex)
            let topY = ys.min()!
            let bottomY = ys.max()!
            let topDist = abs(topY - middleY)
            let bottomDist = abs(bottomY - middleY)
            stemUp = bottomDist >= topDist
        }

        return LayoutNote(
            x: x, ys: ys, noteType: note.noteType, isRest: false, stemUp: stemUp,
            accidentals: accidentals, lyricText: note.lyric?.text, ledgerLineYs: ledgerLineYs,
            beatPosition: beatPosition)
    }
}
