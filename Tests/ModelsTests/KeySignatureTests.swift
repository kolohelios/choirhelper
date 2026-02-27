import Testing

@testable import Models

@Suite("KeySignature")
struct KeySignatureTests {
    @Test("C major display name")
    func cMajor() {
        let key = KeySignature(fifths: 0, mode: .major)
        #expect(key.displayName == "C")
    }

    @Test("G major (1 sharp) display name")
    func gMajor() {
        let key = KeySignature(fifths: 1, mode: .major)
        #expect(key.displayName == "G")
    }

    @Test("Bb major (-2 flats) display name")
    func bbMajor() {
        let key = KeySignature(fifths: -2, mode: .major)
        #expect(key.displayName == "B♭")
    }

    @Test("A minor display name")
    func aMinor() {
        let key = KeySignature(fifths: 0, mode: .minor)
        #expect(key.displayName == "a")
    }

    @Test("Default mode is major")
    func defaultMode() {
        let key = KeySignature(fifths: 0)
        #expect(key.mode == .major)
    }
}
