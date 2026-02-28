import Foundation
import Testing

@testable import Models

@Suite("Measure") struct MeasureTests {
    @Test("Total duration sums note durations") func totalDuration() {
        let measure = Measure(
            number: 1,
            notes: [
                Note(pitch: Pitch(step: .c, octave: 4), duration: 1.0),
                Note(pitch: Pitch(step: .d, octave: 4), duration: 1.0),
                Note(pitch: Pitch(step: .e, octave: 4), duration: 2.0, noteType: .half),
            ])
        #expect(measure.totalDuration == 4.0)
    }

    @Test("Empty measure has zero duration") func emptyMeasure() {
        let measure = Measure(number: 1, notes: [])
        #expect(measure.totalDuration == 0)
    }

    @Test("Measure preserves time signature override") func timeSignatureOverride() {
        let measure = Measure(
            number: 5, notes: [], timeSignature: TimeSignature(beats: 3, beatType: 4))
        #expect(measure.timeSignature?.beats == 3)
    }
}
