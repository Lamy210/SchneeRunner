import Foundation
import SchneeRunnerCore

@MainActor
final class ProductivityStateStore {
    typealias ReplaceItem = (URL, URL) throws -> Void

    private static let applicationDirectoryName = "SchneeRunner"
    private static let productivityDirectoryName = "Productivity"
    private static let stateFileName = "state.json"

    private let fileManager: FileManager
    private let directoryURL: URL
    private let stateURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let replaceItem: ReplaceItem

    init(
        baseDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        directoryURL = baseDirectory
            .appendingPathComponent(Self.applicationDirectoryName, isDirectory: true)
            .appendingPathComponent(Self.productivityDirectoryName, isDirectory: true)
        stateURL = directoryURL.appendingPathComponent(Self.stateFileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        decoder = JSONDecoder()
        replaceItem = { originalURL, stagedURL in
            _ = try fileManager.replaceItemAt(
                originalURL,
                withItemAt: stagedURL,
                backupItemName: nil,
                options: []
            )
        }
    }

    init(
        baseDirectory: URL,
        fileManager: FileManager,
        replaceItem: @escaping ReplaceItem
    ) {
        self.fileManager = fileManager
        directoryURL = baseDirectory
            .appendingPathComponent(Self.applicationDirectoryName, isDirectory: true)
            .appendingPathComponent(Self.productivityDirectoryName, isDirectory: true)
        stateURL = directoryURL.appendingPathComponent(Self.stateFileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        decoder = JSONDecoder()
        self.replaceItem = replaceItem
    }

    func load() throws -> ProductivitySnapshot {
        guard fileManager.fileExists(atPath: stateURL.path) else {
            return ProductivitySnapshot()
        }

        let data = try Data(contentsOf: stateURL)
        return try decoder.decode(ProductivitySnapshot.self, from: data)
    }

    func save(_ snapshot: ProductivitySnapshot) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let stagedURL = directoryURL.appendingPathComponent(
            ".state-\(UUID().uuidString).staging"
        )
        let data = try encoder.encode(snapshot)

        do {
            try data.write(to: stagedURL)
            try synchronizeFile(at: stagedURL)

            if fileManager.fileExists(atPath: stateURL.path) {
                try replaceItem(stateURL, stagedURL)
            } else {
                try fileManager.moveItem(at: stagedURL, to: stateURL)
            }
        } catch {
            try? fileManager.removeItem(at: stagedURL)
            throw error
        }
    }

    private func synchronizeFile(at url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        do {
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }
}
