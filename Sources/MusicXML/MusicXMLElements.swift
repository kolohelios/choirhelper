import Foundation

enum MusicXMLElement: String {
    case scorePartwise = "score-partwise"
    case partList = "part-list"
    case scorePart = "score-part"
    case partName = "part-name"
    case part
    case measure
    case attributes
    case key
    case fifths
    case mode
    case time
    case beats
    case beatType = "beat-type"
    case divisions
    case note
    case rest
    case pitch
    case step
    case alter
    case octave
    case duration
    case type
    case tie
    case lyric
    case text
    case syllabic
    case dynamics
    case direction
    case directionType = "direction-type"
    case sound
    case work
    case workTitle = "work-title"
    case movementTitle = "movement-title"
    case identification
    case creator
    case chord
}

struct PartListEntry {
    let id: String
    var name: String
}
