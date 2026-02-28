import AVFoundation
import Foundation
import Models

public protocol SoundFontManagerProtocol: Sendable { var soundFontURL: URL? { get } }

public final class SoundFontManager: SoundFontManagerProtocol, Sendable {
    public let soundFontURL: URL?

    public init(soundFontName: String = "GeneralUser", bundle: Bundle = .main) {
        self.soundFontURL = bundle.url(forResource: soundFontName, withExtension: "sf2")
    }

    public init(url: URL) { self.soundFontURL = url }
}
