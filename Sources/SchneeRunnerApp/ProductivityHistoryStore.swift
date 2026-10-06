import Foundation
import SchneeRunnerCore

@MainActor
final class ProductivityHistoryStore {
    typealias ReplaceItem = (URL, URL) throws -> Void

    private static let applicationDirectoryName = "SchneeRunner"
    private static let productivityDirectoryName = "Productivity"
    private static let historyFileName = "history.json"

    private let fileManager: FileManager
    private let directoryURL: URL
    private let historyURL: URL
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
        historyURL = directoryURL.appendingPathComponent(Self.historyFileName)

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
        historyURL = directoryURL.appendingPathComponent(Self.historyFileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        decoder = JSONDecoder()
        self.replaceItem = replaceItem
    }

    func load() throws -> ProductivityHistory {
        guard fileManager.fileExists(atPath: historyURL.path) else {
            return ProductivityHistory()
        }

        let data = try Data(contentsOf: historyURL)
        return try decoder.decode(ProductivityHistory.self, from: data)
    }

    func save(_ history: ProductivityHistory) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let stagedURL = directoryURL.appendingPathComponent(
            ".history-\(UUID().uuidString).staging"
        )
        let data = try encoder.encode(history)

        do {
            try data.write(to: stagedURL)
            try synchronizeFile(at: stagedURL)

            if fileManager.fileExists(atPath: historyURL.path) {
                try replaceItem(historyURL, stagedURL)
            } else {
                try fileManager.moveItem(at: stagedURL, to: historyURL)
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
