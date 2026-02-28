import Foundation

public enum ChoirHelperError: Error, Sendable {
    case fileNotFound(String)
    case parsingFailed(String)
    case invalidMusicXML(String)
    case networkError(String)
    case apiKeyMissing
    case apiError(statusCode: Int, message: String)
    case audioEngineError(String)
    case soundFontNotFound(String)
    case storageError(String)
    case encodingError(String)
}

extension ChoirHelperError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path): return "File not found: \(path)"
        case .parsingFailed(let detail): return "Parsing failed: \(detail)"
        case .invalidMusicXML(let detail): return "Invalid MusicXML: \(detail)"
        case .networkError(let detail): return "Network error: \(detail)"
        case .apiKeyMissing: return "OpenRouter API key is not configured"
        case .apiError(let code, let message): return "API error (\(code)): \(message)"
        case .audioEngineError(let detail): return "Audio engine error: \(detail)"
        case .soundFontNotFound(let name): return "SoundFont not found: \(name)"
        case .storageError(let detail): return "Storage error: \(detail)"
        case .encodingError(let detail): return "Encoding error: \(detail)"
        }
    }
}
