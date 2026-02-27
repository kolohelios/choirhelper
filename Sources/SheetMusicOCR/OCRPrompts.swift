import Foundation

enum OCRPrompts {
    static func visionExtractionPrompt(
        userPart: String
    ) -> String {
        """
        Analyze this photograph of sheet music. Extract every musical \
        detail: key/time signatures, tempo, notes (pitch + duration), \
        rests, dynamics, lyrics with syllable alignment, ties, slurs. \
        The user says they sing \(userPart). Identify all parts visible. \
        Output structured text. Mark anything unclear with [UNCLEAR].
        """
    }

    static let musicXMLGenerationPrompt = """
        Convert this musical analysis into valid MusicXML 4.0 \
        score-partwise format. Include all parts, lyrics, dynamics. \
        Output only the XML, no explanation or markdown fences.
        """
}
