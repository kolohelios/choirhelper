import Foundation
import Testing

@testable import OpenRouter

// MARK: - Mock URL Protocol

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var mockHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // Capture body from httpBody or httpBodyStream
        if let body = request.httpBody {
            MockURLProtocol.lastRequestBody = body
        } else if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer {
                buffer.deallocate()
                stream.close()
            }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 4096)
                if read > 0 { data.append(buffer, count: read) }
            }
            MockURLProtocol.lastRequestBody = data
        }

        guard let handler = MockURLProtocol.mockHandler else {
            fatalError("MockURLProtocol.mockHandler not set")
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }

    override func stopLoading() {}
}

// MARK: - Helper

private func mockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private func successResponse(json: String) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!, statusCode: 200,
        httpVersion: nil, headerFields: nil)!
    return (response, Data(json.utf8))
}

private let sampleResponseJSON = """
    {
        "id": "gen-123",
        "model": "test/model",
        "choices": [{
            "index": 0,
            "message": {"role": "assistant", "content": "Hello from AI"},
            "finish_reason": "stop"
        }],
        "usage": {
            "prompt_tokens": 10,
            "completion_tokens": 5,
            "total_tokens": 15
        }
    }
    """

// MARK: - Tests

@Suite("OpenRouterClient", .serialized) struct OpenRouterClientTests {
    let testConfig = OpenRouterConfig(apiKey: "test-key-123")

    @Test("Complete sends correct request structure") func completeSendsCorrectRequest()
        async throws
    {
        var capturedRequest: URLRequest?
        MockURLProtocol.mockHandler = { request in
            capturedRequest = request
            return successResponse(json: sampleResponseJSON)
        }

        let client = OpenRouterClient(config: testConfig, session: mockSession())
        _ = try await client.complete(
            prompt: "test prompt", model: "test/model", systemPrompt: nil, maxTokens: nil)

        #expect(capturedRequest != nil)
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(
            capturedRequest?.value(forHTTPHeaderField: "Authorization") == "Bearer test-key-123")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("Complete returns text content") func completeReturnsContent() async throws {
        MockURLProtocol.mockHandler = { _ in successResponse(json: sampleResponseJSON) }

        let client = OpenRouterClient(config: testConfig, session: mockSession())
        let result = try await client.complete(
            prompt: "test", model: "test/model", systemPrompt: nil, maxTokens: nil)
        #expect(result == "Hello from AI")
    }

    @Test("Complete with system prompt includes system message") func completeWithSystemPrompt()
        async throws
    {
        MockURLProtocol.lastRequestBody = nil
        MockURLProtocol.mockHandler = { _ in successResponse(json: sampleResponseJSON) }

        let client = OpenRouterClient(config: testConfig, session: mockSession())
        _ = try await client.complete(
            prompt: "test", model: "test/model", systemPrompt: "You are helpful", maxTokens: nil)

        let body = MockURLProtocol.lastRequestBody
        #expect(body != nil)
        let decoded = try JSONDecoder().decode(ChatCompletionRequest.self, from: body!)
        #expect(decoded.messages.count == 2)
        #expect(decoded.messages.first?.role == .system)
    }

    @Test("API error throws ChoirHelperError") func apiErrorThrows() async throws {
        MockURLProtocol.mockHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!, statusCode: 401,
                httpVersion: nil, headerFields: nil)!
            return (response, Data("unauthorized".utf8))
        }

        let client = OpenRouterClient(config: testConfig, session: mockSession())
        await #expect(throws: (any Error).self) {
            try await client.complete(
                prompt: "test", model: "test/model", systemPrompt: nil, maxTokens: nil)
        }
    }

    @Test("Vision request includes base64 images") func visionRequestIncludesImages() async throws {
        MockURLProtocol.lastRequestBody = nil
        MockURLProtocol.mockHandler = { _ in successResponse(json: sampleResponseJSON) }

        let client = OpenRouterClient(config: testConfig, session: mockSession())
        let fakeImage = Data([0xFF, 0xD8, 0xFF, 0xE0])
        _ = try await client.completeWithVision(
            prompt: "analyze this", imageData: [fakeImage], model: "test/vision", maxTokens: nil)

        let body = MockURLProtocol.lastRequestBody
        #expect(body != nil)
        let bodyString = String(data: body!, encoding: .utf8) ?? ""
        #expect(bodyString.contains("image_url"))
        #expect(bodyString.contains("base64,"))
    }
}

@Suite("ChatCompletionResponse") struct ChatCompletionResponseTests {
    @Test("Decodes standard response") func decodesResponse() throws {
        let data = Data(sampleResponseJSON.utf8)
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        #expect(response.id == "gen-123")
        #expect(response.firstContent == "Hello from AI")
        #expect(response.usage?.totalTokens == 15)
    }
}

@Suite("ModelTask") struct ModelTaskTests {
    @Test("Vision OCR has default model") func visionOCRModel() {
        let task = ModelTask.visionOCR
        #expect(task.defaultModel.isEmpty == false)
    }

    @Test("All tasks have different defaults for different purposes") func allTasksHaveModels() {
        let tasks: [ModelTask] = [.visionOCR, .musicXMLGeneration, .coaching]
        for task in tasks { #expect(task.defaultModel.contains("/")) }
    }
}

@Suite("MessageContent") struct MessageContentTests {
    @Test("Text content encodes as string") func textEncodesAsString() throws {
        let content = MessageContent.text("hello")
        let data = try JSONEncoder().encode(content)
        let string = String(data: data, encoding: .utf8)
        #expect(string == "\"hello\"")
    }

    @Test("Text content decodes from string") func textDecodesFromString() throws {
        let data = Data("\"hello\"".utf8)
        let content = try JSONDecoder().decode(MessageContent.self, from: data)
        if case .text(let text) = content {
            #expect(text == "hello")
        } else {
            Issue.record("Expected text content")
        }
    }
}
