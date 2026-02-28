import Foundation
import Models

public final class MusicXMLParser: NSObject, Sendable {
    override public init() { super.init() }

    public func parse(data: Data) throws -> Score {
        let handler = MusicXMLHandler()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        guard parser.parse() else {
            let errorMsg = handler.parseError?.localizedDescription ?? "Unknown error"
            throw ChoirHelperError.parsingFailed(errorMsg)
        }
        return try handler.buildScore()
    }

    public func parse(contentsOf url: URL) throws -> Score {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }
}

// MARK: - SAX Handler

private final class MusicXMLHandler: NSObject, XMLParserDelegate {
    var parseError: Error?

    // Score-level
    private var title: String?
    private var composer: String?
    private var globalKeySignature = KeySignature(fifths: 0)
    private var globalTimeSignature = TimeSignature(beats: 4, beatType: 4)
    private var tempo = 120
    private var divisions = 1

    // Part list
    private var partListEntries: [PartListEntry] = []
    private var currentPartId: String?
    private var currentPartName: String?

    // Current parsing state
    private var elementStack: [String] = []
    private var currentText = ""

    // Part/measure/note building
    private var partMeasures: [String: [MeasureBuilder]] = [:]
    private var currentMeasureNumber = 0
    private var inPartList = false
    private var activePartId: String?

    // Note sub-elements
    private var currentStep: Step?
    private var currentAlter = 0
    private var currentOctave = 4
    private var currentDuration = 0
    private var currentNoteType: NoteType = .quarter
    private var currentIsRest = false
    private var currentIsTied = false
    private var currentLyricText: String?
    private var currentSyllabic: Lyric.Syllabic = .single
    private var currentDynamic: Dynamic?
    private var inLyric = false

    // Key/time tracking per measure
    private var pendingKeySignature: KeySignature?
    private var pendingTimeSignature: TimeSignature?

    func buildScore() throws -> Score {
        guard !partListEntries.isEmpty else {
            throw ChoirHelperError.invalidMusicXML("No parts found")
        }

        var parts: [Part] = []
        for (index, entry) in partListEntries.enumerated() {
            let measures = partMeasures[entry.id] ?? []
            let partType = inferPartType(from: entry.name)
            let builtMeasures = measures.map { $0.build() }
            let part = Part(
                name: entry.name, partType: partType, measures: builtMeasures,
                midiChannel: UInt8(index % 16), midiProgram: partType.defaultMidiProgram)
            parts.append(part)
        }

        return Score(
            title: title ?? "Untitled", composer: composer, keySignature: globalKeySignature,
            timeSignature: globalTimeSignature, tempo: tempo, parts: parts)
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
        qualifiedName: String?, attributes: [String: String]
    ) {
        elementStack.append(elementName)
        currentText = ""
        handleStartElement(elementName, attributes: attributes)
    }

    private func handleStartElement(_ elementName: String, attributes: [String: String]) {
        switch elementName {
        case MusicXMLElement.partList.rawValue: inPartList = true
        case MusicXMLElement.scorePart.rawValue:
            currentPartId = attributes["id"]
            currentPartName = nil
        case MusicXMLElement.part.rawValue: activePartId = attributes["id"]
        case MusicXMLElement.measure.rawValue: handleStartMeasure(attributes: attributes)
        case MusicXMLElement.note.rawValue: resetNoteState()
        case MusicXMLElement.rest.rawValue: currentIsRest = true
        case MusicXMLElement.tie.rawValue: if attributes["type"] == "start" { currentIsTied = true }
        case MusicXMLElement.lyric.rawValue: handleStartLyric()
        case MusicXMLElement.sound.rawValue: handleStartSound(attributes: attributes)
        default: break
        }
    }

    private func handleStartMeasure(attributes: [String: String]) {
        if let numStr = attributes["number"], let num = Int(numStr) { currentMeasureNumber = num }
        pendingKeySignature = nil
        pendingTimeSignature = nil
    }

    private func handleStartLyric() {
        inLyric = true
        currentLyricText = nil
        currentSyllabic = .single
    }

    private func handleStartSound(attributes: [String: String]) {
        if let tempoStr = attributes["tempo"], let tempoVal = Double(tempoStr) {
            tempo = Int(tempoVal)
        }
    }

    func parser(
        _ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
        qualifiedName: String?
    ) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        handleEndElement(elementName, text: trimmed)
        if !elementStack.isEmpty { elementStack.removeLast() }
    }

    private func handleEndElement(_ elementName: String, text: String) {
        switch elementName {
        case MusicXMLElement.partName.rawValue: if inPartList { currentPartName = text }
        case MusicXMLElement.scorePart.rawValue: handleEndScorePart()
        case MusicXMLElement.partList.rawValue: inPartList = false
        case MusicXMLElement.fifths.rawValue: handleEndFifths(text)
        case MusicXMLElement.mode.rawValue: handleEndMode(text)
        case MusicXMLElement.beats.rawValue: handleEndBeats(text)
        case MusicXMLElement.beatType.rawValue: handleEndBeatType(text)
        case MusicXMLElement.divisions.rawValue: if let val = Int(text), val > 0 { divisions = val }
        case MusicXMLElement.step.rawValue: currentStep = Step(rawValue: text.lowercased())
        case MusicXMLElement.alter.rawValue: currentAlter = Int(text) ?? 0
        case MusicXMLElement.octave.rawValue: currentOctave = Int(text) ?? 4
        case MusicXMLElement.duration.rawValue: currentDuration = Int(text) ?? 0
        case MusicXMLElement.type.rawValue: handleEndType(text)
        case MusicXMLElement.text.rawValue: if inLyric { currentLyricText = text }
        case MusicXMLElement.syllabic.rawValue:
            if inLyric { currentSyllabic = Lyric.Syllabic(rawValue: text) ?? .single }
        case MusicXMLElement.lyric.rawValue: inLyric = false
        case MusicXMLElement.workTitle.rawValue, MusicXMLElement.movementTitle.rawValue:
            if !text.isEmpty { title = text }
        case MusicXMLElement.creator.rawValue: if !text.isEmpty { composer = text }
        case MusicXMLElement.note.rawValue: finishNote()
        case MusicXMLElement.measure.rawValue: finishMeasure()
        default: break
        }
    }

    private func handleEndScorePart() {
        guard let partId = currentPartId else { return }
        let entry = PartListEntry(id: partId, name: currentPartName ?? partId)
        partListEntries.append(entry)
    }

    private func handleEndFifths(_ text: String) {
        guard let val = Int(text) else { return }
        let sig = KeySignature(fifths: val)
        pendingKeySignature = sig
        if partMeasures.isEmpty || currentMeasureNumber <= 1 { globalKeySignature = sig }
    }

    private func handleEndMode(_ text: String) {
        let modeVal = KeySignature.Mode(rawValue: text) ?? .major
        let fifths = pendingKeySignature?.fifths ?? globalKeySignature.fifths
        let sig = KeySignature(fifths: fifths, mode: modeVal)
        pendingKeySignature = sig
        if partMeasures.isEmpty || currentMeasureNumber <= 1 { globalKeySignature = sig }
    }

    private func handleEndBeats(_ text: String) {
        guard let val = Int(text) else { return }
        let beatType = pendingTimeSignature?.beatType ?? 4
        pendingTimeSignature = TimeSignature(beats: val, beatType: beatType)
    }

    private func handleEndBeatType(_ text: String) {
        guard let val = Int(text) else { return }
        let beats = pendingTimeSignature?.beats ?? 4
        let sig = TimeSignature(beats: beats, beatType: val)
        pendingTimeSignature = sig
        if partMeasures.isEmpty || currentMeasureNumber <= 1 { globalTimeSignature = sig }
    }

    private func handleEndType(_ text: String) {
        guard parentElement() == MusicXMLElement.note.rawValue else { return }
        currentNoteType = parseNoteType(text)
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { currentText += string }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    // MARK: - Private Helpers

    private func parentElement() -> String? {
        elementStack.count >= 2 ? elementStack[elementStack.count - 2] : nil
    }

    private func resetNoteState() {
        currentStep = nil
        currentAlter = 0
        currentOctave = 4
        currentDuration = 0
        currentNoteType = .quarter
        currentIsRest = false
        currentIsTied = false
        currentLyricText = nil
        currentSyllabic = .single
        currentDynamic = nil
    }

    private func finishNote() {
        let durationInQuarters = divisions > 0 ? Double(currentDuration) / Double(divisions) : 1.0

        let pitch: Pitch?
        if !currentIsRest, let step = currentStep {
            pitch = Pitch(step: step, alter: currentAlter, octave: currentOctave)
        } else {
            pitch = nil
        }

        let lyric: Lyric?
        if let text = currentLyricText {
            lyric = Lyric(text: text, syllabic: currentSyllabic)
        } else {
            lyric = nil
        }

        let note = Note(
            pitch: pitch, duration: durationInQuarters, noteType: currentNoteType,
            isRest: currentIsRest, isTied: currentIsTied, lyric: lyric, dynamic: currentDynamic)

        guard let partId = activePartId else { return }
        var measures = partMeasures[partId, default: []]

        if let last = measures.last, last.number == currentMeasureNumber {
            last.notes.append(note)
        } else {
            let builder = MeasureBuilder(number: currentMeasureNumber)
            builder.notes.append(note)
            measures.append(builder)
        }
        partMeasures[partId] = measures
    }

    private func finishMeasure() {
        guard let partId = activePartId else { return }
        guard let measures = partMeasures[partId], let last = measures.last,
            last.number == currentMeasureNumber
        else { return }
        last.keySignature = pendingKeySignature
        last.timeSignature = pendingTimeSignature
    }

    private func parseNoteType(_ value: String) -> NoteType {
        switch value {
        case "whole": return .whole
        case "half": return .half
        case "quarter": return .quarter
        case "eighth": return .eighth
        case "16th": return .sixteenth
        default: return .quarter
        }
    }

    // Ordered list of part name patterns to match (more specific patterns first)
    private static let partTypePatterns: [(keywords: [String], type: PartType)] = [
        (["soprano 1", "soprano i"], .soprano1), (["soprano 2", "soprano ii"], .soprano2),
        (["alto 1", "alto i"], .alto1), (["alto 2", "alto ii"], .alto2),
        (["tenor 1", "tenor i"], .tenor1), (["tenor 2", "tenor ii"], .tenor2),
        (["bass 1", "bass i"], .bass1), (["bass 2", "bass ii"], .bass2), (["soprano"], .soprano),
        (["alto"], .alto), (["tenor"], .tenor), (["bass", "bariton"], .bass),
        (["descant"], .descant), (["piano", "accomp"], .piano),
    ]

    private func inferPartType(from name: String) -> PartType {
        let lower = name.lowercased()
        for (keywords, type) in Self.partTypePatterns
        where keywords.contains(where: { lower.contains($0) }) { return type }
        return .soprano
    }
}

// MARK: - Measure Builder

private final class MeasureBuilder {
    let number: Int
    var notes: [Note] = []
    var keySignature: KeySignature?
    var timeSignature: TimeSignature?

    init(number: Int) { self.number = number }

    func build() -> Measure { Measure(number: number, notes: notes, keySignature: keySignature) }
}
