import Foundation

public enum CharacterPackStoreError: Error, Equatable, LocalizedError {
    case wrongAssetKind(CharacterAssetKind)
    case assetDirectoryMissing(UUID)
    case invalidAssetDirectory(URL)
    case symbolicLinkNotAllowed(URL)

    public var errorDescription: String? {
        switch self {
        case let .wrongAssetKind(kind):
            "Expected character pack asset, received \(kind.rawValue)."
        case let .assetDirectoryMissing(id):
            "Character pack asset \(id.uuidString) was not found."
        case let .invalidAssetDirectory(url):
            "Character pack asset directory is invalid: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for stored character packs: \(url.lastPathComponent)."
        }
    }
}

public struct CharacterPackStore {
    public let rootDirectory: URL

    private static let packageDirectoryName = "pack.schneerunnerpack"
    private static let manifestFileName = "manifest.json"

    private let fileManager: FileManager
    private let loader: CharacterPackLoader
    private let encoder: JSONEncoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        loader: CharacterPackLoader? = nil
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.loader = loader ?? CharacterPackLoader(
            fileManager: fileManager
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func importPack(
        from sourceURL: URL,
        createdAt: Date = Date()
    ) throws -> StoredCharacterAsset {
        let loadedPack = try loader.load(from: sourceURL)
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let asset = StoredCharacterAsset(
            schemaVersion: CharacterAssetStore.currentSchemaVersion,
            id: UUID(),
            displayName: loadedPack.displayName,
            kind: .characterPack,
            createdAt: Self.normalizedTimestamp(createdAt)
        )
        try persist(
            asset: asset,
            sourceURL: sourceURL
        )
        return asset
    }

    public func load(
        for asset: StoredCharacterAsset
    ) throws -> LoadedCharacterPack {
        guard asset.kind == .characterPack else {
            throw CharacterPackStoreError.wrongAssetKind(asset.kind)
        }

        let directory = assetDirectory(id: asset.id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw CharacterPackStoreError.assetDirectoryMissing(asset.id)
        }

        try validateDirectory(directory)
        let packageURL = directory.appendingPathComponent(
            Self.packageDirectoryName,
            isDirectory: true
        )
        return try loader.load(from: packageURL)
    }

    private func persist(
        asset: StoredCharacterAsset,
        sourceURL: URL
    ) throws {
        let stagingDirectory = rootDirectory.appendingPathComponent(
            ".staging-\(asset.id.uuidString)",
            isDirectory: true
        )
        let finalDirectory = assetDirectory(id: asset.id)

        try? fileManager.removeItem(at: stagingDirectory)
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: false
        )

        do {
            try writePack(
                asset: asset,
                sourceURL: sourceURL,
                stagingDirectory: stagingDirectory
            )
            try fileManager.moveItem(
                at: stagingDirectory,
                to: finalDirectory
            )
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }

    private func writePack(
        asset: StoredCharacterAsset,
        sourceURL: URL,
        stagingDirectory: URL
    ) throws {
        let copiedURL = stagingDirectory.appendingPathComponent(
            Self.packageDirectoryName,
            isDirectory: true
        )
        try fileManager.copyItem(
            at: sourceURL,
            to: copiedURL
        )
        _ = try loader.load(from: copiedURL)

        try encoder.encode(asset).write(
            to: stagingDirectory.appendingPathComponent(
                Self.manifestFileName
            ),
            options: .atomic
        )
    }

    private static func normalizedTimestamp(_ date: Date) -> Date {
        Date(
            timeIntervalSince1970: floor(
                date.timeIntervalSince1970
            )
        )
    }

    private func assetDirectory(id: UUID) -> URL {
        rootDirectory.appendingPathComponent(
            id.uuidString,
            isDirectory: true
        )
    }

    private func validateDirectory(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackStoreError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw CharacterPackStoreError.invalidAssetDirectory(url)
        }
    }
}
