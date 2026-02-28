import Models
import SwiftUI

/// Three-line teleprompter view showing previous, current, and next lines of notation.
/// Auto-advances as playback progresses.
public struct TeleprompterView: View {
    let layout: NotationLayout
    let currentBeat: Double
    let showLyrics: Bool
    let showMeasureNumbers: Bool
    let onSeek: ((Double) -> Void)?

    public init(
        layout: NotationLayout, currentBeat: Double, showLyrics: Bool = true,
        showMeasureNumbers: Bool = true, onSeek: ((Double) -> Void)? = nil
    ) {
        self.layout = layout
        self.currentBeat = currentBeat
        self.showLyrics = showLyrics
        self.showMeasureNumbers = showMeasureNumbers
        self.onSeek = onSeek
    }

    private var currentLineIndex: Int { layout.lineIndex(forBeat: currentBeat) ?? 0 }

    public var body: some View {
        VStack(spacing: 4) {
            // Previous line (faded)
            lineView(at: currentLineIndex - 1, opacity: 0.3)

            // Current line (full)
            lineView(at: currentLineIndex, opacity: 1.0)

            // Next line (slightly faded)
            lineView(at: currentLineIndex + 1, opacity: 0.6)
        }.animation(.easeInOut(duration: 0.3), value: currentLineIndex)
    }

    @ViewBuilder private func lineView(at index: Int, opacity: Double) -> some View {
        if index >= 0, index < layout.lines.count {
            let line = layout.lines[index]
            NotationCanvasView(
                line: line, staffGeometry: layout.staffGeometry,
                currentBeat: opacity == 1.0 ? currentBeat : nil, showLyrics: showLyrics,
                showMeasureNumbers: showMeasureNumbers
            ).opacity(opacity).id(index).overlay {
                if let onSeek {
                    Color.clear.contentShape(Rectangle())
                        .onTapGesture { location in
                            if let beat = line.beatPosition(forX: location.x) {
                                onSeek(beat)
                            }
                        }
                }
            }
        } else {
            // Empty placeholder to maintain layout
            Color.clear.frame(height: layout.staffGeometry.staffSpacing * 8)
        }
    }
}
