import Foundation

public struct Lyric: Codable, Sendable, Hashable {
    public let text: String
    public let syllabic: Syllabic

    public init(text: String, syllabic: Syllabic = .single) {
        self.text = text
        self.syllabic = syllabic
    }

    public enum Syllabic: String, Codable, Sendable {
        case single
        case begin
        case middle
        case end
    }
}
