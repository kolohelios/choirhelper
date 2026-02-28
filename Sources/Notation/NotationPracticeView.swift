import Models
import SwiftUI

/// Full practice notation view with teleprompter, context parts, and toggle controls.
public struct NotationPracticeView: View {
    let score: Score
    let currentBeat: Double
    let onSeek: ((Double) -> Void)?

    @State private var showOtherParts = false
    @State private var showLyrics = true
    @State private var showMeasureNumbers = true

    public init(score: Score, currentBeat: Double, onSeek: ((Double) -> Void)? = nil) {
        self.score = score
        self.currentBeat = currentBeat
        self.onSeek = onSeek
    }

    private var userParts: [Part] { score.userParts }

    private var contextParts: [Part] {
        score.vocalParts.filter { !score.userPartTypes.contains($0.partType) }
    }

    public var body: some View {
        VStack(spacing: 0) {
            toggleControls

            Divider()

            ScrollView {
                VStack(spacing: 12) {
                    primaryPartViews
                    if showOtherParts { contextPartViews }
                }.padding(.vertical, 8)
            }
        }
    }

    // MARK: - Toggle Controls

    private var toggleControls: some View {
        HStack(spacing: 16) {
            Toggle("Other parts", isOn: $showOtherParts)
            Toggle("Lyrics", isOn: $showLyrics)
            Toggle("Measure numbers", isOn: $showMeasureNumbers)
        }.toggleStyle(.switch).padding(.horizontal, 16).padding(.vertical, 8)
    }

    // MARK: - Primary Parts

    private var primaryPartViews: some View {
        ForEach(userParts) { part in
            VStack(alignment: .leading, spacing: 2) {
                Text(part.name).font(.caption).foregroundStyle(.secondary).padding(.leading, 8)

                GeometryReader { geo in
                    let geometry = StaffGeometry(
                        staffSpacing: 8, clefType: part.partType.clefType,
                        octaveTransposition: part.partType.octaveTransposition)
                    let engine = NotationLayoutEngine(
                        staffGeometry: geometry, availableWidth: geo.size.width)
                    let layout = engine.layout(part: part)

                    TeleprompterView(
                        layout: layout, keySignature: score.keySignature,
                        timeSignature: score.timeSignature,
                        currentBeat: currentBeat, showLyrics: showLyrics,
                        showMeasureNumbers: showMeasureNumbers, onSeek: onSeek)
                }.frame(height: primaryPartHeight)
            }
        }
    }

    // MARK: - Context Parts

    private var contextPartViews: some View {
        ForEach(contextParts) { part in
            VStack(alignment: .leading, spacing: 2) {
                Text(part.name).font(.caption2).foregroundStyle(.tertiary).padding(.leading, 8)

                GeometryReader { geo in
                    let geometry = StaffGeometry(
                        staffSpacing: 5, clefType: part.partType.clefType,
                        octaveTransposition: part.partType.octaveTransposition)
                    let engine = NotationLayoutEngine(
                        staffGeometry: geometry, availableWidth: geo.size.width)
                    let layout = engine.layout(part: part)

                    currentLineView(layout: layout, staffGeometry: geometry)
                }.frame(height: contextPartHeight).opacity(0.5)
            }
        }
    }

    /// Show only the current line for context parts (no teleprompter).
    @ViewBuilder private func currentLineView(
        layout: NotationLayout, staffGeometry: StaffGeometry
    ) -> some View {
        let lineIndex = layout.lineIndex(forBeat: currentBeat) ?? 0
        if lineIndex < layout.lines.count {
            NotationCanvasView(
                line: layout.lines[lineIndex], staffGeometry: staffGeometry,
                keySignature: score.keySignature, timeSignature: score.timeSignature,
                showLyrics: showLyrics, showMeasureNumbers: showMeasureNumbers)
        }
    }

    // MARK: - Layout Constants

    private var primaryPartHeight: CGFloat { 220 }
    private var contextPartHeight: CGFloat { 60 }
}
