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

    /// Binary search for the first event index at or after the given beat.
    public func eventIndex(forBeat beat: Double) -> Int {
        var lo = 0, hi = events.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if events[mid].startBeat < beat { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }
}

public struct MIDIScheduler: Sendable {
    public init() {}

    /// Small gap (in beats) inserted before non-tied note boundaries so the
    /// sampler produces a re-articulation between consecutive same-pitch notes.
    private static let articulationGap: Double = 0.05

    public func schedule(score: Score) -> MIDISchedule {
        var events: [MIDIEvent] = []
        var maxBeat: Double = 0

        for (partIndex, part) in score.parts.enumerated() {
            var currentBeat: Double = 0

            // Flatten all notes across measures so we can look ahead for ties.
            let allNotes = part.measures.flatMap { measure in
                measure.notes.map { (note: $0, measureNumber: measure.number) }
            }

            for (noteIndex, entry) in allNotes.enumerated() {
                let note = entry.note
                if !note.isRest {
                    // If this note is tied forward, accumulate duration with
                    // the following note(s) rather than emitting now.
                    if note.isTied {
                        currentBeat += note.duration
                        continue
                    }

                    // Walk backwards to collect duration from preceding tied notes.
                    var totalDuration = note.duration
                    var startBeat = currentBeat
                    var lookback = noteIndex - 1
                    while lookback >= 0 {
                        let prev = allNotes[lookback].note
                        guard prev.isTied, !prev.isRest,
                            prev.pitches.map(\.midiNumber) == note.pitches.map(\.midiNumber)
                        else { break }
                        totalDuration += prev.duration
                        startBeat -= prev.duration
                        lookback -= 1
                    }

                    // Shorten slightly so consecutive same-pitch notes re-articulate.
                    let gap = min(Self.articulationGap, totalDuration * 0.25)
                    let sounding = totalDuration - gap

                    let velocity: UInt8 = velocityFor(dynamic: note.dynamic)
                    for pitch in note.pitches {
                        let midiNote = UInt8(clamping: pitch.midiNumber)
                        let event = MIDIEvent(
                            partIndex: partIndex, midiNote: midiNote, velocity: velocity,
                            startBeat: startBeat, durationBeats: sounding,
                            measureNumber: entry.measureNumber, noteIndex: noteIndex)
                        events.append(event)
                    }
                }
                currentBeat += note.duration
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
