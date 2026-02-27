import Foundation
import Models

public protocol OpenRouterClientProtocol: Sendable {
    func complete(
        request: ChatCompletionRequest
    ) async throws -> ChatCompletionResponse

    func complete(
        prompt: String,
        model: String,
        systemPrompt: String?,
        maxTokens: Int?
    ) async throws -> String

    func completeWithVision(
        prompt: String,
        imageData: [Data],
        model: String,
        maxTokens: Int?
    ) async throws -> String
}

public actor OpenRouterClient: OpenRouterClientProtocol {
    private let config: OpenRouterConfig
    private let session: URLSession

    public init(config: OpenRouterConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func complete(
        request: ChatCompletionRequest
    ) async throws -> ChatCompletionResponse {
        let url = config.baseURL.appendingPathComponent("chat/completions")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "Bearer \(config.apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue(
            config.httpReferer,
            forHTTPHeaderField: "HTTP-Referer"
        )
        urlRequest.setValue(
            config.appTitle,
            forHTTPHeaderField: "X-Title"
        )

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChoirHelperError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw ChoirHelperError.apiError(
                statusCode: httpResponse.statusCode, message: body
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode(ChatCompletionResponse.self, from: data)
    }

    public func complete(
        prompt: String,
        model: String,
        systemPrompt: String? = nil,
        maxTokens: Int? = nil
    ) async throws -> String {
        var messages: [Message] = []
        if let systemPrompt {
            messages.append(
                Message(role: .system, content: .text(systemPrompt))
            )
        }
        messages.append(Message(role: .user, content: .text(prompt)))

        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            maxTokens: maxTokens
        )
        let response = try await complete(request: request)
        guard let content = response.firstContent else {
            throw ChoirHelperError.apiError(
                statusCode: 0, message: "Empty response"
            )
        }
        return content
    }

    public func completeWithVision(
        prompt: String,
        imageData: [Data],
        model: String,
        maxTokens: Int? = nil
    ) async throws -> String {
        var parts: [ContentPart] = imageData.map { data in
            let base64 = data.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64)"
            return .imageURL(ContentPart.ImageURL(url: dataURL))
        }
        parts.append(.text(prompt))

        let message = Message(role: .user, content: .parts(parts))
        let request = ChatCompletionRequest(
            model: model,
            messages: [message],
            maxTokens: maxTokens
        )
        let response = try await complete(request: request)
        guard let content = response.firstContent else {
            throw ChoirHelperError.apiError(
                statusCode: 0, message: "Empty response"
            )
        }
        return content
    }
}
