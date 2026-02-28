import Foundation
import Models

public protocol ScoreStorageProtocol: Sendable {
    func save(score: Score) async throws
    func load(id: UUID) async throws -> Score
    func loadAll() async throws -> [Score]
    func delete(id: UUID) async throws
}

public actor ScoreStorage: ScoreStorageProtocol {
    private let baseDirectory: URL

    public init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            // Try iCloud Documents, fall back to local
            let fileManager = FileManager.default
            if let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
                .appendingPathComponent("Documents")
            {
                self.baseDirectory = iCloudURL
            } else if let appSupport = fileManager.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            ).first {
                self.baseDirectory = appSupport.appendingPathComponent("ChoirHelper")
                    .appendingPathComponent("Scores")
            } else {
                self.baseDirectory = fileManager.temporaryDirectory.appendingPathComponent(
                    "ChoirHelper"
                ).appendingPathComponent("Scores")
            }
        }
    }

    public func save(score: Score) throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: baseDirectory.path) {
            try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(score)

        let fileURL = baseDirectory.appendingPathComponent(score.id.uuidString)
            .appendingPathExtension("choirhelper")
        try data.write(to: fileURL, options: .atomic)
    }

    public func load(id: UUID) throws -> Score {
        let fileURL = baseDirectory.appendingPathComponent(id.uuidString).appendingPathExtension(
            "choirhelper")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ChoirHelperError.fileNotFound(fileURL.path)
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(Score.self, from: data)
    }

    public func loadAll() throws -> [Score] {
        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: baseDirectory.path) else { return [] }

        let contents = try fileManager.contentsOfDirectory(
            at: baseDirectory, includingPropertiesForKeys: nil)

        let scoreFiles = contents.filter { $0.pathExtension == "choirhelper" }

        var scores: [Score] = []
        for file in scoreFiles {
            let data = try Data(contentsOf: file)
            if let score = try? JSONDecoder().decode(Score.self, from: data) {
                scores.append(score)
            }
        }

        return scores.sorted { $0.title < $1.title }
    }

    public func delete(id: UUID) throws {
        let fileURL = baseDirectory.appendingPathComponent(id.uuidString).appendingPathExtension(
            "choirhelper")

        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        try FileManager.default.removeItem(at: fileURL)
    }
}
