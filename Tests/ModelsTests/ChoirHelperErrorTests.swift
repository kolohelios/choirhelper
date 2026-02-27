import Foundation
import Testing

@testable import Models

@Suite("ChoirHelperError")
struct ChoirHelperErrorTests {
    @Test("Error descriptions are human-readable")
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

    @Test("API key missing has specific message")
    func apiKeyMissingMessage() {
        let error = ChoirHelperError.apiKeyMissing
        #expect(error.localizedDescription.contains("API key"))
    }
}
