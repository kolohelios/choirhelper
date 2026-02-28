import Foundation
import Testing

@testable import Models
@testable import Storage

@Suite("ScoreStorage") struct ScoreStorageTests {
    static func tempDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    static func sampleScore() -> Score {
        Score(
            title: "Test Score", composer: "Tester", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120,
            parts: [
                Part(
                    name: "Soprano", partType: .soprano,
                    measures: [
                        Measure(
                            number: 1,
                            notes: [
                                Note(
                                    pitch: Pitch(step: .c, octave: 4), duration: 4.0,
                                    noteType: .whole)
                            ])
                    ], midiChannel: 0, midiProgram: 52)
            ])
    }

    @Test("Save and load round-trip") func saveAndLoad() async throws {
        let dir = ScoreStorageTests.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = ScoreStorage(baseDirectory: dir)
        let original = ScoreStorageTests.sampleScore()
        try await storage.save(score: original)

        let loaded = try await storage.load(id: original.id)
        #expect(loaded.title == original.title)
        #expect(loaded.composer == original.composer)
        #expect(loaded.parts.count == original.parts.count)
    }

    @Test("Load all returns saved scores") func loadAll() async throws {
        let dir = ScoreStorageTests.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = ScoreStorage(baseDirectory: dir)
        let score1 = Score(
            title: "Alpha", keySignature: KeySignature(fifths: 0),
            timeSignature: TimeSignature(beats: 4, beatType: 4), tempo: 120, parts: [])
        let score2 = Score(
            title: "Beta", keySignature: KeySignature(fifths: 1),
            timeSignature: TimeSignature(beats: 3, beatType: 4), tempo: 100, parts: [])

        try await storage.save(score: score1)
        try await storage.save(score: score2)

        let all = try await storage.loadAll()
        #expect(all.count == 2)
        // Sorted alphabetically
        #expect(all[0].title == "Alpha")
        #expect(all[1].title == "Beta")
    }

    @Test("Delete removes score") func deleteScore() async throws {
        let dir = ScoreStorageTests.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = ScoreStorage(baseDirectory: dir)
        let score = ScoreStorageTests.sampleScore()
        try await storage.save(score: score)
        try await storage.delete(id: score.id)

        await #expect(throws: ChoirHelperError.self) { try await storage.load(id: score.id) }
    }

    @Test("Load nonexistent throws fileNotFound") func loadNonexistent() async throws {
        let dir = ScoreStorageTests.tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let storage = ScoreStorage(baseDirectory: dir)
        await #expect(throws: ChoirHelperError.self) { try await storage.load(id: UUID()) }
    }

    @Test("Load all from empty directory returns empty") func loadAllEmpty() async throws {
        let dir = ScoreStorageTests.tempDir()
        let storage = ScoreStorage(baseDirectory: dir)
        let all = try await storage.loadAll()
        #expect(all.isEmpty)
    }
}

@Suite("PracticeHistory") struct PracticeHistoryTests {
    @Test("Record and retrieve sessions") func recordAndRetrieve() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let history = PracticeHistory(directory: dir)
        let scoreId = UUID()
        let session = PracticeSession(scoreId: scoreId, durationSeconds: 120, partTypes: [.tenor])
        try await history.record(session: session)

        let sessions = try await history.sessions(for: scoreId)
        #expect(sessions.count == 1)
        #expect(sessions[0].durationSeconds == 120)
    }

    @Test("Sessions filtered by score ID") func filteredByScoreId() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }

        let history = PracticeHistory(directory: dir)
        let scoreId1 = UUID()
        let scoreId2 = UUID()

        try await history.record(
            session: PracticeSession(scoreId: scoreId1, durationSeconds: 60, partTypes: [.tenor]))
        try await history.record(
            session: PracticeSession(scoreId: scoreId2, durationSeconds: 90, partTypes: [.soprano]))

        let sessions1 = try await history.sessions(for: scoreId1)
        #expect(sessions1.count == 1)

        let all = try await history.allSessions()
        #expect(all.count == 2)
    }
}

@Suite("PracticeSession") struct PracticeSessionTests {
    @Test("Codable round-trip") func codableRoundTrip() throws {
        let session = PracticeSession(
            scoreId: UUID(), durationSeconds: 180, partTypes: [.tenor, .bass])
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(PracticeSession.self, from: data)
        #expect(decoded.id == session.id)
        #expect(decoded.durationSeconds == session.durationSeconds)
        #expect(decoded.partTypes == session.partTypes)
    }
}

@Suite("SettingsStorage") struct SettingsStorageTests {
    @Test("Default part types is tenor") func defaultPartTypes() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = SettingsStorage(
            keychainService: "test.\(UUID().uuidString)", defaults: defaults)
        let types = await settings.getUserPartTypes()
        #expect(types == [.tenor])
    }

    @Test("Set and get part types") func setAndGetPartTypes() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let settings = SettingsStorage(
            keychainService: "test.\(UUID().uuidString)", defaults: defaults)
        await settings.setUserPartTypes([.soprano, .descant])
        let types = await settings.getUserPartTypes()
        #expect(types == [.soprano, .descant])
    }
}
