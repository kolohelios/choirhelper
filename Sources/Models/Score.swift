import Foundation

public struct Score: Codable, Sendable, Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var composer: String?
    public var keySignature: KeySignature
    public var timeSignature: TimeSignature
    public var tempo: Int
    public var parts: [Part]
    public var userPartTypes: [PartType]

    public init(
        id: UUID = UUID(), title: String, composer: String? = nil, keySignature: KeySignature,
        timeSignature: TimeSignature, tempo: Int, parts: [Part],
        userPartTypes: [PartType] = [.tenor]
    ) {
        self.id = id
        self.title = title
        self.composer = composer
        self.keySignature = keySignature
        self.timeSignature = timeSignature
        self.tempo = tempo
        self.parts = parts
        self.userPartTypes = userPartTypes
    }

    public var vocalParts: [Part] { parts.filter(\.isVocal) }

    public var accompanimentParts: [Part] { parts.filter { !$0.isVocal } }

    public var userParts: [Part] { parts.filter { userPartTypes.contains($0.partType) } }

    public var measureCount: Int { parts.first?.measures.count ?? 0 }

    public var durationSeconds: Double {
        guard let firstPart = parts.first, !firstPart.measures.isEmpty else { return 0 }
        let totalBeats = firstPart.measures.reduce(0.0) { $0 + $1.totalDuration }
        return totalBeats / Double(tempo) * 60.0
    }
}
