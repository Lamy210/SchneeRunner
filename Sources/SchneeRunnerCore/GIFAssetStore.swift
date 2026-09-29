import Foundation

public enum GIFAssetStoreError: Error, Equatable, LocalizedError {
    case wrongAssetKind(CharacterAssetKind)
    case assetDirectoryMissing(UUID)
    case invalidAssetDirectory(URL)
    case symbolicLinkNotAllowed(URL)
    case sourceIsNotRegularFile(URL)

    public var errorDescription: String? {
        switch self {
        case let .wrongAssetKind(kind):
            "Expected GIF asset, received \(kind.rawValue)."
        case let .assetDirectoryMissing(id):
            "GIF asset \(id.uuidString) was not found."
        case let .invalidAssetDirectory(url):
            "GIF asset directory is invalid: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for GIF assets: \(url.lastPathComponent)."
        case let .sourceIsNotRegularFile(url):
            "GIF source is not a regular file: \(url.lastPathComponent)."
        }
    }
}

public struct GIFAssetStore {
    public let rootDirectory: URL

    private static let sourceFileName = "source.gif"
    private static let manifestFileName = "manifest.json"

    private let fileManager: FileManager
    private let loader: GIFAnimationLoader
    private let encoder: JSONEncoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        loader: GIFAnimationLoader = .init()
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.loader = loader

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func importGIF(
        from sourceURL: URL,
        createdAt: Date = Date()
    ) throws -> StoredCharacterAsset {
        try loader.validate(url: sourceURL)
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let id = UUID()
        let asset = StoredCharacterAsset(
            schemaVersion: CharacterAssetStore.currentSchemaVersion,
            id: id,
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            kind: .gif,
            createdAt: Self.normalizedTimestamp(createdAt)
        )
        let stagingDirectory = rootDirectory.appendingPathComponent(
            ".staging-\(id.uuidString)",
            isDirectory: true
        )
        let finalDirectory = assetDirectory(id: id)

        try? fileManager.removeItem(at: stagingDirectory)
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: false
        )

        do {
            let copiedURL = stagingDirectory.appendingPathComponent(
                Self.sourceFileName
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
            try fileManager.moveItem(
                at: stagingDirectory,
                to: finalDirectory
            )
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }

        return asset
    }

    public func sourceURL(
        for asset: StoredCharacterAsset
    ) throws -> URL {
        guard asset.kind == .gif else {
            throw GIFAssetStoreError.wrongAssetKind(asset.kind)
        }

        let directory = assetDirectory(id: asset.id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw GIFAssetStoreError.assetDirectoryMissing(asset.id)
        }

        try validateDirectory(directory)
        let sourceURL = directory.appendingPathComponent(
            Self.sourceFileName
        )
        try validateSourceFile(sourceURL)
        try loader.validate(url: sourceURL)
        return sourceURL
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
            throw GIFAssetStoreError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw GIFAssetStoreError.invalidAssetDirectory(url)
        }
    }

    private func validateSourceFile(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw GIFAssetStoreError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw GIFAssetStoreError.sourceIsNotRegularFile(url)
        }
    }
}
