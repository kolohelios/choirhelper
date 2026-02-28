import Foundation

public struct OpenRouterConfig: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let httpReferer: String
    public let appTitle: String

    // swiftlint:disable:next force_unwrapping
    public static let defaultBaseURL = URL(string: "https://openrouter.ai/api/v1")!

    public init(
        apiKey: String, baseURL: URL = OpenRouterConfig.defaultBaseURL,
        httpReferer: String = "https://github.com/kolohelios/choirhelper",
        appTitle: String = "ChoirHelper"
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.httpReferer = httpReferer
        self.appTitle = appTitle
    }
}
