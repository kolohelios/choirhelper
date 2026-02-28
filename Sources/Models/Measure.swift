import Foundation

public struct Measure: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let number: Int
    public let notes: [Note]
    public let timeSignature: TimeSignature?
    public let keySignature: KeySignature?

    public init(
        id: UUID = UUID(), number: Int, notes: [Note], timeSignature: TimeSignature? = nil,
        keySignature: KeySignature? = nil
    ) {
        self.id = id
        self.number = number
        self.notes = notes
        self.timeSignature = timeSignature
        self.keySignature = keySignature
    }

    public var totalDuration: Double { notes.reduce(0) { $0 + $1.duration } }
}
