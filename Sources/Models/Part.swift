import Foundation

public struct Part: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var partType: PartType
    public var measures: [Measure]
    public var midiChannel: UInt8
    public var midiProgram: UInt8

    public init(
        id: UUID = UUID(), name: String, partType: PartType, measures: [Measure],
        midiChannel: UInt8, midiProgram: UInt8
    ) {
        self.id = id
        self.name = name
        self.partType = partType
        self.measures = measures
        self.midiChannel = midiChannel
        self.midiProgram = midiProgram
    }

    public var isVocal: Bool { partType.isVocal }
}

public enum ClefType: String, Codable, Sendable {
    case treble
    case bass
}

public enum PartType: String, Codable, Sendable, CaseIterable, Hashable {
    case soprano
    case alto
    case tenor
    case bass
    case piano
    case soprano1
    case soprano2
    case alto1
    case alto2
    case tenor1
    case tenor2
    case bass1
    case bass2
    case descant
    case accompaniment

    public var isVocal: Bool {
        switch self {
        case .piano, .accompaniment: return false
        default: return true
        }
    }

    public var displayName: String {
        switch self {
        case .soprano: "Soprano"
        case .alto: "Alto"
        case .tenor: "Tenor"
        case .bass: "Bass"
        case .piano: "Piano"
        case .soprano1: "Soprano 1"
        case .soprano2: "Soprano 2"
        case .alto1: "Alto 1"
        case .alto2: "Alto 2"
        case .tenor1: "Tenor 1"
        case .tenor2: "Tenor 2"
        case .bass1: "Bass 1"
        case .bass2: "Bass 2"
        case .descant: "Descant"
        case .accompaniment: "Accompaniment"
        }
    }

    public var defaultMidiProgram: UInt8 {
        switch self {
        case .piano, .accompaniment: 0
        default: 52
        }
    }

    public var clefType: ClefType {
        switch self {
        case .bass, .bass1, .bass2: .bass
        default: .treble
        }
    }
}
