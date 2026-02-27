import Foundation

public struct Note: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public let pitch: Pitch?
    public let duration: Double
    public let noteType: NoteType
    public let isRest: Bool
    public let isTied: Bool
    public let lyric: Lyric?
    public let dynamic: Dynamic?

    public init(
        id: UUID = UUID(),
        pitch: Pitch? = nil,
        duration: Double,
        noteType: NoteType = .quarter,
        isRest: Bool = false,
        isTied: Bool = false,
        lyric: Lyric? = nil,
        dynamic: Dynamic? = nil
    ) {
        self.id = id
        self.pitch = pitch
        self.duration = duration
        self.noteType = noteType
        self.isRest = isRest
        self.isTied = isTied
        self.lyric = lyric
        self.dynamic = dynamic
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
