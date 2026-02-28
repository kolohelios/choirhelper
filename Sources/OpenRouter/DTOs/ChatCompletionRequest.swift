import Foundation

public struct ChatCompletionRequest: Codable, Sendable {
    public let model: String
    public let messages: [Message]
    public let maxTokens: Int?
    public let temperature: Double?

    public init(
        model: String, messages: [Message], maxTokens: Int? = nil, temperature: Double? = nil
    ) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

public struct Message: Codable, Sendable {
    public let role: Role
    public let content: MessageContent

    public init(role: Role, content: MessageContent) {
        self.role = role
        self.content = content
    }

    public enum Role: String, Codable, Sendable { case system, user, assistant }
}

public enum MessageContent: Codable, Sendable {
    case text(String)
    case parts([ContentPart])

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string): try container.encode(string)
        case .parts(let parts): try container.encode(parts)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
        } else {
            let parts = try container.decode([ContentPart].self)
            self = .parts(parts)
        }
    }
}

public enum ContentPart: Codable, Sendable {
    case text(String)
    case imageURL(ImageURL)

    enum CodingKeys: String, CodingKey {
        case type, text
        case imageUrl = "image_url"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let string):
            try container.encode("text", forKey: .type)
            try container.encode(string, forKey: .text)
        case .imageURL(let imageURL):
            try container.encode("image_url", forKey: .type)
            try container.encode(imageURL, forKey: .imageUrl)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageURL = try container.decode(ImageURL.self, forKey: .imageUrl)
            self = .imageURL(imageURL)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown content type: \(type)")
        }
    }

    public struct ImageURL: Codable, Sendable {
        public let url: String
        public let detail: String?

        public init(url: String, detail: String? = "high") {
            self.url = url
            self.detail = detail
        }
    }
}
