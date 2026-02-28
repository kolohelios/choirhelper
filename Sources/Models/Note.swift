import Foundation

public struct Note: Sendable, Identifiable, Hashable {
    public let id: UUID
    public let pitches: [Pitch]
    public let duration: Double
    public let noteType: NoteType
    public let isRest: Bool
    public let isTied: Bool
    public let lyric: Lyric?
    public let dynamic: Dynamic?

    public var pitch: Pitch? { pitches.first }
    public var isChord: Bool { pitches.count > 1 }

    public init(
        id: UUID = UUID(), pitches: [Pitch], duration: Double, noteType: NoteType = .quarter,
        isRest: Bool = false, isTied: Bool = false, lyric: Lyric? = nil, dynamic: Dynamic? = nil
    ) {
        self.id = id
        self.pitches = pitches
        self.duration = duration
        self.noteType = noteType
        self.isRest = isRest
        self.isTied = isTied
        self.lyric = lyric
        self.dynamic = dynamic
    }

    public init(
        id: UUID = UUID(), pitch: Pitch? = nil, duration: Double, noteType: NoteType = .quarter,
        isRest: Bool = false, isTied: Bool = false, lyric: Lyric? = nil, dynamic: Dynamic? = nil
    ) {
        self.id = id
        self.pitches = pitch.map { [$0] } ?? []
        self.duration = duration
        self.noteType = noteType
        self.isRest = isRest
        self.isTied = isTied
        self.lyric = lyric
        self.dynamic = dynamic
    }
}

extension Note: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, pitches, pitch, duration, noteType, isRest, isTied, lyric, dynamic
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        if let multi = try container.decodeIfPresent([Pitch].self, forKey: .pitches) {
            pitches = multi
        } else if let single = try container.decodeIfPresent(Pitch.self, forKey: .pitch) {
            pitches = [single]
        } else {
            pitches = []
        }
        duration = try container.decode(Double.self, forKey: .duration)
        noteType = try container.decode(NoteType.self, forKey: .noteType)
        isRest = try container.decode(Bool.self, forKey: .isRest)
        isTied = try container.decode(Bool.self, forKey: .isTied)
        lyric = try container.decodeIfPresent(Lyric.self, forKey: .lyric)
        dynamic = try container.decodeIfPresent(Dynamic.self, forKey: .dynamic)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(pitches, forKey: .pitches)
        try container.encode(duration, forKey: .duration)
        try container.encode(noteType, forKey: .noteType)
        try container.encode(isRest, forKey: .isRest)
        try container.encode(isTied, forKey: .isTied)
        try container.encodeIfPresent(lyric, forKey: .lyric)
        try container.encodeIfPresent(dynamic, forKey: .dynamic)
    }
}

public enum NoteType: String, Codable, Sendable, CaseIterable {
    case whole
    case half
    case quarter
    case eighth
    case sixteenth

    public var relativeDuration: Double {
        switch self {
        case .whole: 4.0
        case .half: 2.0
        case .quarter: 1.0
        case .eighth: 0.5
        case .sixteenth: 0.25
        }
    }
}

public enum Dynamic: String, Codable, Sendable, CaseIterable {
    case ppp, pp, p, mp, mf, f, ff, fff
    case crescendo, decrescendo
}
