import Foundation

public struct TimeSignature: Codable, Sendable, Hashable {
    public let beats: Int
    public let beatType: Int

    public init(beats: Int, beatType: Int) {
        self.beats = beats
        self.beatType = beatType
    }

    public var displayName: String {
        "\(beats)/\(beatType)"
    }

    public var beatsPerMeasure: Double {
        Double(beats)
    }

    public var beatDuration: Double {
        4.0 / Double(beatType)
    }
}
