import Foundation
import Models

public final class MusicXMLParser: NSObject, Sendable {
    public override init() {
        super.init()
    }

    public func parse(data: Data) throws -> Score {
        let handler = MusicXMLHandler()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        guard parser.parse() else {
            let errorMsg =
                handler.parseError?.localizedDescription ?? "Unknown error"
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
                name: entry.name,
                partType: partType,
                measures: builtMeasures,
                midiChannel: UInt8(index % 16),
                midiProgram: partType.defaultMidiProgram
            )
            parts.append(part)
        }

        return Score(
            title: title ?? "Untitled",
            composer: composer,
            keySignature: globalKeySignature,
            timeSignature: globalTimeSignature,
            tempo: tempo,
            parts: parts
        )
    }

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        elementStack.append(elementName)
        currentText = ""

        switch elementName {
        case MusicXMLElement.partList.rawValue:
            inPartList = true

        case MusicXMLElement.scorePart.rawValue:
            currentPartId = attributes["id"]
            currentPartName = nil

        case MusicXMLElement.part.rawValue:
            activePartId = attributes["id"]

        case MusicXMLElement.measure.rawValue:
            if let numStr = attributes["number"], let num = Int(numStr) {
                currentMeasureNumber = num
            }
            pendingKeySignature = nil
            pendingTimeSignature = nil

        case MusicXMLElement.note.rawValue:
            resetNoteState()

        case MusicXMLElement.rest.rawValue:
            currentIsRest = true

        case MusicXMLElement.tie.rawValue:
            if attributes["type"] == "start" {
                currentIsTied = true
            }

        case MusicXMLElement.lyric.rawValue:
            inLyric = true
            currentLyricText = nil
            currentSyllabic = .single

        case MusicXMLElement.sound.rawValue:
            if let tempoStr = attributes["tempo"],
                let tempoVal = Double(tempoStr)
            {
                tempo = Int(tempoVal)
            }

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let trimmed = currentText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        switch elementName {
        case MusicXMLElement.partName.rawValue:
            if inPartList {
                currentPartName = trimmed
            }

        case MusicXMLElement.scorePart.rawValue:
            if let partId = currentPartId {
                let entry = PartListEntry(
                    id: partId,
                    name: currentPartName ?? partId
                )
                partListEntries.append(entry)
            }

        case MusicXMLElement.partList.rawValue:
            inPartList = false

        case MusicXMLElement.fifths.rawValue:
            if let val = Int(trimmed) {
                let sig = KeySignature(fifths: val)
                pendingKeySignature = sig
                if partMeasures.isEmpty || currentMeasureNumber <= 1 {
                    globalKeySignature = sig
                }
            }

        case MusicXMLElement.mode.rawValue:
            let modeVal =
                KeySignature.Mode(rawValue: trimmed) ?? .major
            let fifths = pendingKeySignature?.fifths
                ?? globalKeySignature.fifths
            let sig = KeySignature(fifths: fifths, mode: modeVal)
            pendingKeySignature = sig
            if partMeasures.isEmpty || currentMeasureNumber <= 1 {
                globalKeySignature = sig
            }

        case MusicXMLElement.beats.rawValue:
            if let val = Int(trimmed) {
                let beatType = pendingTimeSignature?.beatType ?? 4
                let sig = TimeSignature(beats: val, beatType: beatType)
                pendingTimeSignature = sig
            }

        case MusicXMLElement.beatType.rawValue:
            if let val = Int(trimmed) {
                let beats = pendingTimeSignature?.beats ?? 4
                let sig = TimeSignature(beats: beats, beatType: val)
                pendingTimeSignature = sig
                if partMeasures.isEmpty || currentMeasureNumber <= 1 {
                    globalTimeSignature = sig
                }
            }

        case MusicXMLElement.divisions.rawValue:
            if let val = Int(trimmed), val > 0 {
                divisions = val
            }

        case MusicXMLElement.step.rawValue:
            currentStep = Step(rawValue: trimmed.lowercased())

        case MusicXMLElement.alter.rawValue:
            currentAlter = Int(trimmed) ?? 0

        case MusicXMLElement.octave.rawValue:
            currentOctave = Int(trimmed) ?? 4

        case MusicXMLElement.duration.rawValue:
            currentDuration = Int(trimmed) ?? 0

        case MusicXMLElement.type.rawValue:
            if parentElement() == MusicXMLElement.note.rawValue {
                currentNoteType = parseNoteType(trimmed)
            }

        case MusicXMLElement.text.rawValue:
            if inLyric {
                currentLyricText = trimmed
            }

        case MusicXMLElement.syllabic.rawValue:
            if inLyric {
                currentSyllabic =
                    Lyric.Syllabic(rawValue: trimmed) ?? .single
            }

        case MusicXMLElement.lyric.rawValue:
            inLyric = false

        case MusicXMLElement.workTitle.rawValue,
            MusicXMLElement.movementTitle.rawValue:
            if !trimmed.isEmpty {
                title = trimmed
            }

        case MusicXMLElement.creator.rawValue:
            if !trimmed.isEmpty {
                composer = trimmed
            }

        case MusicXMLElement.note.rawValue:
            finishNote()

        case MusicXMLElement.measure.rawValue:
            finishMeasure()

        default:
            break
        }

        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        parseErrorOccurred parseError: Error
    ) {
        self.parseError = parseError
    }

    // MARK: - Private Helpers

    private func parentElement() -> String? {
        elementStack.count >= 2
            ? elementStack[elementStack.count - 2] : nil
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
        let durationInQuarters = divisions > 0
            ? Double(currentDuration) / Double(divisions) : 1.0

        let pitch: Pitch?
        if !currentIsRest, let step = currentStep {
            pitch = Pitch(
                step: step, alter: currentAlter, octave: currentOctave
            )
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
            pitch: pitch,
            duration: durationInQuarters,
            noteType: currentNoteType,
            isRest: currentIsRest,
            isTied: currentIsTied,
            lyric: lyric,
            dynamic: currentDynamic
        )

        guard let partId = activePartId else { return }
        if partMeasures[partId] == nil {
            partMeasures[partId] = []
        }

        let measures = partMeasures[partId]!
        if let last = measures.last,
            last.number == currentMeasureNumber
        {
            last.notes.append(note)
        } else {
            let builder = MeasureBuilder(number: currentMeasureNumber)
            builder.notes.append(note)
            partMeasures[partId]!.append(builder)
        }
    }

    private func finishMeasure() {
        guard let partId = activePartId else { return }
        if let measures = partMeasures[partId],
            let last = measures.last,
            last.number == currentMeasureNumber
        {
            last.keySignature = pendingKeySignature
            last.timeSignature = pendingTimeSignature
        }
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

    private func inferPartType(from name: String) -> PartType {
        let lower = name.lowercased()
        if lower.contains("soprano 1") || lower.contains("soprano i") {
            return .soprano1
        }
        if lower.contains("soprano 2") || lower.contains("soprano ii") {
            return .soprano2
        }
        if lower.contains("alto 1") || lower.contains("alto i") {
            return .alto1
        }
        if lower.contains("alto 2") || lower.contains("alto ii") {
            return .alto2
        }
        if lower.contains("tenor 1") || lower.contains("tenor i") {
            return .tenor1
        }
        if lower.contains("tenor 2") || lower.contains("tenor ii") {
            return .tenor2
        }
        if lower.contains("bass 1") || lower.contains("bass i") {
            return .bass1
        }
        if lower.contains("bass 2") || lower.contains("bass ii") {
            return .bass2
        }
        if lower.contains("soprano") { return .soprano }
        if lower.contains("alto") { return .alto }
        if lower.contains("tenor") { return .tenor }
        if lower.contains("bass") || lower.contains("bariton") {
            return .bass
        }
        if lower.contains("descant") { return .descant }
        if lower.contains("piano") || lower.contains("accomp") {
            return .piano
        }
        return .soprano
    }
}

// MARK: - Measure Builder

private final class MeasureBuilder {
    let number: Int
    var notes: [Note] = []
    var keySignature: KeySignature?
    var timeSignature: TimeSignature?

    init(number: Int) {
        self.number = number
    }

    func build() -> Measure {
        Measure(
            number: number,
            notes: notes,
            keySignature: keySignature
        )
    }
}
