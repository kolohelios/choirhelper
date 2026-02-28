import Foundation
import Models

public struct MIDIEvent: Sendable, Equatable {
    public let partIndex: Int
    public let midiNote: UInt8
    public let velocity: UInt8
    public let startBeat: Double
    public let durationBeats: Double
    public let measureNumber: Int
    public let noteIndex: Int

    public var endBeat: Double { startBeat + durationBeats }

    public init(
        partIndex: Int, midiNote: UInt8, velocity: UInt8, startBeat: Double, durationBeats: Double,
        measureNumber: Int, noteIndex: Int
    ) {
        self.partIndex = partIndex
        self.midiNote = midiNote
        self.velocity = velocity
        self.startBeat = startBeat
        self.durationBeats = durationBeats
        self.measureNumber = measureNumber
        self.noteIndex = noteIndex
    }
}

public struct MIDISchedule: Sendable {
    public let events: [MIDIEvent]
    public let totalBeats: Double
    public let tempo: Int

    public var totalSeconds: Double { totalBeats / Double(tempo) * 60.0 }

    public init(events: [MIDIEvent], totalBeats: Double, tempo: Int) {
        self.events = events
        self.totalBeats = totalBeats
        self.tempo = tempo
    }
}

public struct MIDIScheduler: Sendable {
    public init() {}

    public func schedule(score: Score) -> MIDISchedule {
        var events: [MIDIEvent] = []
        var maxBeat: Double = 0

        for (partIndex, part) in score.parts.enumerated() {
            var currentBeat: Double = 0

            for measure in part.measures {
                for (noteIndex, note) in measure.notes.enumerated() {
                    if !note.isRest, let pitch = note.pitch {
                        let midiNote = UInt8(clamping: pitch.midiNumber)
                        let velocity: UInt8 = velocityFor(dynamic: note.dynamic)
                        let event = MIDIEvent(
                            partIndex: partIndex, midiNote: midiNote, velocity: velocity,
                            startBeat: currentBeat, durationBeats: note.duration,
                            measureNumber: measure.number, noteIndex: noteIndex)
                        events.append(event)
                    }
                    currentBeat += note.duration
                }
            }
            maxBeat = max(maxBeat, currentBeat)
        }

        events.sort { $0.startBeat < $1.startBeat }

        return MIDISchedule(events: events, totalBeats: maxBeat, tempo: score.tempo)
    }

    private func velocityFor(dynamic: Dynamic?) -> UInt8 {
        guard let dynamic else { return 80 }
        switch dynamic {
        case .ppp: return 20
        case .pp: return 35
        case .p: return 50
        case .mp: return 65
        case .mf: return 80
        case .f: return 95
        case .ff: return 110
        case .fff: return 127
        case .crescendo, .decrescendo: return 80
        }
    }
}
