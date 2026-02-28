import Foundation

public struct KeySignature: Codable, Sendable, Hashable {
    public let fifths: Int
    public let mode: Mode

    public init(fifths: Int, mode: Mode = .major) {
        self.fifths = fifths
        self.mode = mode
    }

    public var displayName: String {
        let majorKeys = [
            -7: "C♭", -6: "G♭", -5: "D♭", -4: "A♭", -3: "E♭", -2: "B♭", -1: "F", 0: "C", 1: "G",
            2: "D", 3: "A", 4: "E", 5: "B", 6: "F♯", 7: "C♯",
        ]
        let minorKeys = [
            -7: "a♭", -6: "e♭", -5: "b♭", -4: "f", -3: "c", -2: "g", -1: "d", 0: "a", 1: "e",
            2: "b", 3: "f♯", 4: "c♯", 5: "g♯", 6: "d♯", 7: "a♯",
        ]
        let keys = mode == .major ? majorKeys : minorKeys
        return keys[fifths] ?? "?"
    }

    public enum Mode: String, Codable, Sendable {
        case major
        case minor
    }
}
