import Testing

@testable import Models

@Suite("TimeSignature")
struct TimeSignatureTests {
    @Test("4/4 display name")
    func fourFour() {
        let ts = TimeSignature(beats: 4, beatType: 4)
        #expect(ts.displayName == "4/4")
    }

    @Test("3/4 display name")
    func threeFour() {
        let ts = TimeSignature(beats: 3, beatType: 4)
        #expect(ts.displayName == "3/4")
    }

    @Test("Beats per measure")
    func beatsPerMeasure() {
        let ts = TimeSignature(beats: 6, beatType: 8)
        #expect(ts.beatsPerMeasure == 6.0)
    }

    @Test("Beat duration in quarter notes")
    func beatDuration() {
        let fourFour = TimeSignature(beats: 4, beatType: 4)
        #expect(fourFour.beatDuration == 1.0)

        let sixEight = TimeSignature(beats: 6, beatType: 8)
        #expect(sixEight.beatDuration == 0.5)
    }
}
