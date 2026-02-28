import Foundation

public enum ModelTask: Sendable {
    case visionOCR
    case musicXMLGeneration
    case coaching

    public var defaultModel: String {
        switch self {
        case .visionOCR: return "google/gemini-2.0-flash-001"
        case .musicXMLGeneration: return "anthropic/claude-sonnet-4"
        case .coaching: return "anthropic/claude-sonnet-4"
        }
    }
}
