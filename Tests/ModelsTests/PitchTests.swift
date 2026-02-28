import Foundation
import Testing

@testable import Models

@Suite("Pitch") struct PitchTests {
    @Test("Middle C is MIDI 60") func middleCMidi() {
        let middleC = Pitch(step: .c, octave: 4)
        #expect(middleC.midiNumber == 60)
    }

    @Test("A4 is MIDI 69") func concertAMidi() {
        let a4 = Pitch(step: .a, octave: 4)
        #expect(a4.midiNumber == 69)
    }

    @Test("A4 frequency is 440 Hz") func concertAFrequency() {
        let a4 = Pitch(step: .a, octave: 4)
        #expect(abs(a4.frequency - 440.0) < 0.01)
    }

    @Test("Middle C frequency is ~261.63 Hz") func middleCFrequency() {
        let middleC = Pitch(step: .c, octave: 4)
        #expect(abs(middleC.frequency - 261.63) < 0.01)
    }

    @Test("Sharp raises MIDI number by 1") func sharpRaises() {
        let fSharp = Pitch(step: .f, alter: 1, octave: 4)
        let fNatural = Pitch(step: .f, octave: 4)
        #expect(fSharp.midiNumber == fNatural.midiNumber + 1)
    }

    @Test("Flat lowers MIDI number by 1") func flatLowers() {
        let bFlat = Pitch(step: .b, alter: -1, octave: 4)
        let bNatural = Pitch(step: .b, octave: 4)
        #expect(bFlat.midiNumber == bNatural.midiNumber - 1)
    }

    @Test("Display name includes step and octave") func displayNameBasic() {
        let pitch = Pitch(step: .c, octave: 4)
        #expect(pitch.displayName == "C4")
    }

    @Test("Display name includes sharp symbol") func displayNameSharp() {
        let pitch = Pitch(step: .f, alter: 1, octave: 4)
        #expect(pitch.displayName == "F♯4")
    }

    @Test("Display name includes flat symbol") func displayNameFlat() {
        let pitch = Pitch(step: .b, alter: -1, octave: 3)
        #expect(pitch.displayName == "B♭3")
    }

    @Test("Pitch is Codable round-trip") func codableRoundTrip() throws {
        let original = Pitch(step: .e, alter: -1, octave: 5)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Pitch.self, from: data)
        #expect(decoded == original)
    }

    @Test("Octave boundaries are correct") func octaveBoundaries() {
        let c3 = Pitch(step: .c, octave: 3)
        let c4 = Pitch(step: .c, octave: 4)
        #expect(c4.midiNumber - c3.midiNumber == 12)
    }
}
