import Foundation
import Models

public struct PracticeSession: Codable, Sendable, Identifiable {
    public let id: UUID
    public let scoreId: UUID
    public let date: Date
    public let durationSeconds: Double
    public let partTypes: [PartType]

    public init(
        id: UUID = UUID(), scoreId: UUID, date: Date = Date(), durationSeconds: Double,
        partTypes: [PartType]
    ) {
        self.id = id
        self.scoreId = scoreId
        self.date = date
        self.durationSeconds = durationSeconds
        self.partTypes = partTypes
    }
}

public protocol PracticeHistoryProtocol: Sendable {
    func record(session: PracticeSession) async throws
    func sessions(for scoreId: UUID) async throws -> [PracticeSession]
    func allSessions() async throws -> [PracticeSession]
}

public actor PracticeHistory: PracticeHistoryProtocol {
    private let fileURL: URL

    public init(directory: URL? = nil) {
        let baseDir: URL
        if let directory {
            baseDir = directory
        } else {
            let fileManager = FileManager.default
            if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
            {
                baseDir = iCloudURL
            } else if let appSupport = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first {
                baseDir = appSupport.appendingPathComponent("ChoirHelper")
            } else {
                baseDir = fileManager.temporaryDirectory.appendingPathComponent("ChoirHelper")
            }
        }
        self.fileURL = baseDir.appendingPathComponent("practice_history.json")
    }

    public func record(session: PracticeSession) throws {
        var sessions = (try? loadSessions()) ?? []
        sessions.append(session)
        try saveSessions(sessions)
    }

    public func sessions(for scoreId: UUID) throws -> [PracticeSession] {
        let all = (try? loadSessions()) ?? []
        return all.filter { $0.scoreId == scoreId }.sorted { $0.date > $1.date }
    }

    public func allSessions() throws -> [PracticeSession] { (try? loadSessions()) ?? [] }

    private func loadSessions() throws -> [PracticeSession] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([PracticeSession].self, from: data)
    }

    private func saveSessions(_ sessions: [PracticeSession]) throws {
        let dir = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(sessions)
        try data.write(to: fileURL, options: .atomic)
    }
}
