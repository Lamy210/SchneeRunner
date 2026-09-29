import Foundation

public enum CharacterAssetKind: String, Codable, Equatable, Sendable {
    case singleImage
    case spriteSheet4x2
    case pngSequence
    case gif
    case characterPack
}

public struct StoredCharacterAsset: Codable, Equatable, Identifiable, Sendable {
    public let schemaVersion: Int
    public let id: UUID
    public let displayName: String
    public let kind: CharacterAssetKind
    public let createdAt: Date

    public init(
        schemaVersion: Int = 1,
        id: UUID,
        displayName: String,
        kind: CharacterAssetKind,
        createdAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.createdAt = createdAt
    }
}

public enum CharacterAssetStoreError: Error, Equatable, LocalizedError {
    case sourceIsNotRegularFile(URL)
    case symbolicLinkNotAllowed(URL)
    case unsupportedFileType(String)
    case sequenceRequiresMultipleSources
    case gifRequiresDedicatedStore
    case characterPackRequiresDedicatedStore
    case assetNotFound(UUID)
    case invalidManifest(URL)
    case manifestIdentityMismatch(expected: UUID, actual: UUID)
    case unsupportedSchemaVersion(Int)

    public var errorDescription: String? {
        switch self {
        case let .sourceIsNotRegularFile(url):
            "The selected source is not a regular file: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for character assets: \(url.lastPathComponent)."
        case let .unsupportedFileType(fileExtension):
            "Only PNG character sources are currently supported. Received .\(fileExtension)."
        case .sequenceRequiresMultipleSources:
            "PNG sequences must be imported through the sequence asset store."
        case .gifRequiresDedicatedStore:
            "GIF assets must be imported through the GIF asset store."
        case .characterPackRequiresDedicatedStore:
            "Character packs must be imported through the character pack store."
        case let .assetNotFound(id):
            "Character asset \(id.uuidString) was not found."
        case let .invalidManifest(url):
            "The character manifest is invalid: \(url.lastPathComponent)."
        case let .manifestIdentityMismatch(expected, actual):
            "Character manifest ID \(actual.uuidString) does not match directory \(expected.uuidString)."
        case let .unsupportedSchemaVersion(version):
            "Character manifest schema version \(version) is not supported."
        }
    }
}

public struct CharacterAssetStore {
    public static let currentSchemaVersion = 1

    public let rootDirectory: URL

    private static let sourceFileName = "source.png"
    private static let manifestFileName = "manifest.json"

    private let fileManager: FileManager
    private let imageValidator: ImageAssetValidator
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        imageValidator: ImageAssetValidator = .init()
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.imageValidator = imageValidator

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func importAsset(
        from sourceURL: URL,
        kind: CharacterAssetKind,
        createdAt: Date = Date()
    ) throws -> StoredCharacterAsset {
        try validateImportSource(
            sourceURL,
            kind: kind
        )
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let asset = StoredCharacterAsset(
            schemaVersion: Self.currentSchemaVersion,
            id: UUID(),
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            kind: kind,
            createdAt: Self.normalizedTimestamp(createdAt)
        )
        try persistSingleSource(
            asset: asset,
            sourceURL: sourceURL
        )
        return asset
    }

    private func validateImportSource(
        _ sourceURL: URL,
        kind: CharacterAssetKind
    ) throws {
        switch kind {
        case .pngSequence:
            throw CharacterAssetStoreError.sequenceRequiresMultipleSources
        case .gif:
            throw CharacterAssetStoreError.gifRequiresDedicatedStore
        case .characterPack:
            throw CharacterAssetStoreError.characterPackRequiresDedicatedStore
        case .singleImage, .spriteSheet4x2:
            break
        }

        let resourceValues = try sourceURL.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard resourceValues.isSymbolicLink != true else {
            throw CharacterAssetStoreError.symbolicLinkNotAllowed(sourceURL)
        }
        guard resourceValues.isRegularFile == true else {
            throw CharacterAssetStoreError.sourceIsNotRegularFile(sourceURL)
        }

        let fileExtension = sourceURL.pathExtension.lowercased()
        guard fileExtension == "png" else {
            throw CharacterAssetStoreError.unsupportedFileType(fileExtension)
        }

        _ = try imageValidator.validate(url: sourceURL)
    }

    private func persistSingleSource(
        asset: StoredCharacterAsset,
        sourceURL: URL
    ) throws {
        let stagingDirectory = rootDirectory.appendingPathComponent(
            ".staging-\(asset.id.uuidString)",
            isDirectory: true
        )
        let finalDirectory = directoryURL(for: asset.id)

        try? fileManager.removeItem(at: stagingDirectory)
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: false
        )

        do {
            try writeSingleSourceAsset(
                asset,
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

    private func writeSingleSourceAsset(
        _ asset: StoredCharacterAsset,
        sourceURL: URL,
        stagingDirectory: URL
    ) throws {
        let copiedSourceURL = stagingDirectory
            .appendingPathComponent(Self.sourceFileName)
        try fileManager.copyItem(
            at: sourceURL,
            to: copiedSourceURL
        )
        try validateRegularNonSymlinkFile(at: copiedSourceURL)

        try encoder.encode(asset).write(
            to: stagingDirectory.appendingPathComponent(Self.manifestFileName),
            options: .atomic
        )
    }

    public func listAssets() throws -> [StoredCharacterAsset] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else {
            return []
        }

        let directories = try fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        return directories.compactMap { directory in
            guard
                let values = try? directory.resourceValues(
                    forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
                ),
                values.isDirectory == true,
                values.isSymbolicLink != true
            else {
                return nil
            }

            return try? readManifest(in: directory)
        }
        .sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }

            return lhs.createdAt > rhs.createdAt
        }
    }

    public func asset(id: UUID) throws -> StoredCharacterAsset {
        let directory = directoryURL(for: id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw CharacterAssetStoreError.assetNotFound(id)
        }

        return try readManifest(in: directory)
    }

    public func sourceURL(for asset: StoredCharacterAsset) throws -> URL {
        switch asset.kind {
        case .pngSequence:
            throw CharacterAssetStoreError.sequenceRequiresMultipleSources
        case .gif:
            throw CharacterAssetStoreError.gifRequiresDedicatedStore
        case .characterPack:
            throw CharacterAssetStoreError.characterPackRequiresDedicatedStore
        case .singleImage, .spriteSheet4x2:
            break
        }

        _ = try self.asset(id: asset.id)

        let sourceURL = directoryURL(for: asset.id)
            .appendingPathComponent(Self.sourceFileName)
        try validateRegularNonSymlinkFile(at: sourceURL)
        return sourceURL
    }

    public func removeAsset(id: UUID) throws {
        let directory = directoryURL(for: id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw CharacterAssetStoreError.assetNotFound(id)
        }

        try fileManager.removeItem(at: directory)
    }

    private static func normalizedTimestamp(_ date: Date) -> Date {
        Date(
            timeIntervalSince1970: floor(
                date.timeIntervalSince1970
            )
        )
    }

    private func directoryURL(for id: UUID) -> URL {
        rootDirectory.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    private func readManifest(in directory: URL) throws -> StoredCharacterAsset {
        let directoryID = try validatedDirectoryID(for: directory)
        let manifestURL = directory.appendingPathComponent(Self.manifestFileName)

        do {
            let data = try Data(contentsOf: manifestURL)
            let asset = try decoder.decode(StoredCharacterAsset.self, from: data)

            guard asset.schemaVersion == Self.currentSchemaVersion else {
                throw CharacterAssetStoreError.unsupportedSchemaVersion(
                    asset.schemaVersion
                )
            }
            guard asset.id == directoryID else {
                throw CharacterAssetStoreError.manifestIdentityMismatch(
                    expected: directoryID,
                    actual: asset.id
                )
            }

            return asset
        } catch let error as CharacterAssetStoreError {
            throw error
        } catch {
            throw CharacterAssetStoreError.invalidManifest(manifestURL)
        }
    }

    private func validatedDirectoryID(for directory: URL) throws -> UUID {
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard
            values.isDirectory == true,
            values.isSymbolicLink != true,
            let id = UUID(uuidString: directory.lastPathComponent)
        else {
            throw CharacterAssetStoreError.invalidManifest(directory)
        }

        return id
    }

    private func validateRegularNonSymlinkFile(at url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterAssetStoreError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw CharacterAssetStoreError.sourceIsNotRegularFile(url)
        }
    }
}
