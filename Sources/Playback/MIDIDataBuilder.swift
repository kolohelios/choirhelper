import AudioToolbox
import Foundation
import Models

enum MIDIDataBuilder {
    /// Converts a `MIDISchedule` into Standard MIDI File (Type 1) data.
    ///
    /// Layout: tempo track + one track per part, 480 ticks/quarter.
    /// All note events use MIDI channel 0 (routing is handled by
    /// `AVAudioSequencer` track → `AVAudioUnitSampler` mapping).
    static func buildSMFData(from schedule: MIDISchedule, partCount: Int) throws -> Data {
        var sequence: MusicSequence?
        var status = NewMusicSequence(&sequence)
        guard status == noErr, let sequence else {
            throw ChoirHelperError.audioEngineError("Failed to create MusicSequence: \(status)")
        }
        defer { DisposeMusicSequence(sequence) }

        // Tempo track — single tempo event at beat 0
        var tempoTrack: MusicTrack?
        status = MusicSequenceGetTempoTrack(sequence, &tempoTrack)
        guard status == noErr, let tempoTrack else {
            throw ChoirHelperError.audioEngineError("Failed to get tempo track: \(status)")
        }
        status = MusicTrackNewExtendedTempoEvent(tempoTrack, 0, Float64(schedule.tempo))
        guard status == noErr else {
            throw ChoirHelperError.audioEngineError("Failed to add tempo event: \(status)")
        }

        // One track per part
        let groupedByPart = Dictionary(grouping: schedule.events) { $0.partIndex }
        for partIndex in 0..<partCount {
            try addTrack(to: sequence, partIndex: partIndex, events: groupedByPart[partIndex] ?? [])
        }

        // Export as SMF Type 1, 480 ticks/quarter
        var cfData: Unmanaged<CFData>?
        status = MusicSequenceFileCreateData(
            sequence, .midiType, .eraseFile, 480, &cfData)
        guard status == noErr, let cfData else {
            throw ChoirHelperError.audioEngineError("Failed to export MIDI data: \(status)")
        }
        let data = cfData.takeRetainedValue() as Data
        return data
    }

    private static func addTrack(
        to sequence: MusicSequence, partIndex: Int, events: [MIDIEvent]
    ) throws {
        var track: MusicTrack?
        var status = MusicSequenceNewTrack(sequence, &track)
        guard status == noErr, let track else {
            throw ChoirHelperError.audioEngineError("Failed to create track \(partIndex): \(status)")
        }
        for event in events {
            var noteMessage = MIDINoteMessage(
                channel: 0, note: event.midiNote, velocity: event.velocity,
                releaseVelocity: 0, duration: Float32(event.durationBeats))
            status = MusicTrackNewMIDINoteEvent(track, event.startBeat, &noteMessage)
            guard status == noErr else {
                throw ChoirHelperError.audioEngineError("Failed to add note event: \(status)")
            }
        }
    }
}
