import Foundation
import Models
import OpenRouter

public protocol SheetMusicScannerProtocol: Sendable {
    func scan(images: [Data], userPartDescription: String) async throws -> String
}

public actor SheetMusicScanner: SheetMusicScannerProtocol {
    private let client: OpenRouterClientProtocol

    public init(client: OpenRouterClientProtocol) { self.client = client }

    public func scan(images: [Data], userPartDescription: String) async throws -> String {
        // Phase 2: Two-pass OCR pipeline
        // Pass 1: Vision extraction
        // Pass 2: MusicXML generation
        throw ChoirHelperError.apiError(
            statusCode: 0, message: "OCR pipeline not yet implemented (Phase 2)")
    }
}
