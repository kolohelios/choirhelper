import Foundation
import Testing

@testable import Models

@Suite("ChoirHelperError")
struct ChoirHelperErrorTests {
    @Test("All error cases produce non-empty descriptions")
    func errorDescriptions() {
        let errors: [ChoirHelperError] = [
            .fileNotFound("/path/to/file"),
            .parsingFailed("unexpected token"),
            .invalidMusicXML("missing part-list"),
            .networkError("timeout"),
            .apiKeyMissing,
            .apiError(statusCode: 401, message: "unauthorized"),
            .audioEngineError("failed to start"),
            .soundFontNotFound("GeneralUser.sf2"),
            .storageError("iCloud unavailable"),
            .encodingError("invalid UTF-8"),
        ]

        for error in errors {
            #expect(error.localizedDescription.isEmpty == false)
        }
    }

    @Test("API key missing mentions API key")
    func apiKeyMissingMessage() {
        let error = ChoirHelperError.apiKeyMissing
        #expect(error.localizedDescription.contains("API key"))
    }

    @Test("API error includes status code")
    func apiErrorIncludesStatusCode() {
        let error = ChoirHelperError.apiError(
            statusCode: 429, message: "rate limited"
        )
        #expect(error.localizedDescription.contains("429"))
    }
}
