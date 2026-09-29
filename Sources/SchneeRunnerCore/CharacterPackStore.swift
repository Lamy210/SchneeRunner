import Foundation

public enum CharacterPackStoreError: Error, Equatable, LocalizedError {
    case wrongAssetKind(CharacterAssetKind)
    case assetDirectoryMissing(UUID)
    case invalidAssetDirectory(URL)
    case symbolicLinkNotAllowed(URL)
    case fileSizeUnavailable(URL)
    case packageTooLarge(actual: Int, maximum: Int)

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
        case let .fileSizeUnavailable(url):
            "Could not determine character pack file size: \(url.lastPathComponent)."
        case let .packageTooLarge(actual, maximum):
            "Character pack uses \(actual) bytes, exceeding the \(maximum)-byte limit."
        }
    }
}

public struct CharacterPackStore {
    public static let packageDirectoryName = "package.schneerunner"

    public let rootDirectory: URL
    public let maximumPackageBytes: Int

    private static let assetManifestFileName = "manifest.json"

    private let fileManager: FileManager
    private let loader: CharacterPackLoader
    private let canonicalizer: CharacterPackCanonicalizer
    private let encoder: JSONEncoder

    public init(
        rootDirectory: URL,
        maximumPackageBytes: Int = 128 * 1024 * 1024,
        fileManager: FileManager = .default,
        loader: CharacterPackLoader = .init()
    ) {
        let maximumPackageBytes = max(maximumPackageBytes, 1)

        self.rootDirectory = rootDirectory
        self.maximumPackageBytes = maximumPackageBytes
        self.fileManager = fileManager
        self.loader = loader
        canonicalizer = CharacterPackCanonicalizer(
            maximumPackageBytes: maximumPackageBytes,
            fileManager: fileManager,
            loader: loader
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func importPack(
        from sourcePackageURL: URL,
        createdAt: Date = Date()
    ) throws -> StoredCharacterAsset {
        let manifest = try loader.validatedManifest(
            from: sourcePackageURL
        )
        _ = try loader.load(from: sourcePackageURL)

        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let asset = StoredCharacterAsset(
            schemaVersion: CharacterAssetStore.currentSchemaVersion,
            id: UUID(),
            displayName: manifest.name,
            kind: .characterPack,
            createdAt: Self.normalizedTimestamp(createdAt)
        )
        try persist(
            asset: asset,
            sourcePackageURL: sourcePackageURL,
            manifest: manifest
        )
        return asset
    }

    public func library(
        for asset: StoredCharacterAsset
    ) throws -> CharacterAnimationLibrary {
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
        try validateDirectory(packageURL)
        return try loader.load(from: packageURL)
    }

    private func persist(
        asset: StoredCharacterAsset,
        sourcePackageURL: URL,
        manifest: CharacterPackManifest
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
            try writeStagedAsset(
                asset,
                sourcePackageURL: sourcePackageURL,
                manifest: manifest,
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

    private func writeStagedAsset(
        _ asset: StoredCharacterAsset,
        sourcePackageURL: URL,
        manifest: CharacterPackManifest,
        stagingDirectory: URL
    ) throws {
        let packageURL = stagingDirectory.appendingPathComponent(
            Self.packageDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: packageURL,
            withIntermediateDirectories: false
        )

        let canonicalManifest = try canonicalizer.copyReferencedClips(
            manifest,
            sourcePackageURL: sourcePackageURL,
            destinationPackageURL: packageURL
        )
        try writePackManifest(
            canonicalManifest,
            packageURL: packageURL
        )
        _ = try loader.load(from: packageURL)
        try writeAssetManifest(
            asset,
            stagingDirectory: stagingDirectory
        )
    }

    private func writePackManifest(
        _ manifest: CharacterPackManifest,
        packageURL: URL
    ) throws {
        try encoder.encode(manifest).write(
            to: packageURL.appendingPathComponent(
                CharacterPackLoader.manifestFileName
            ),
            options: .atomic
        )
    }

    private func writeAssetManifest(
        _ asset: StoredCharacterAsset,
        stagingDirectory: URL
    ) throws {
        try encoder.encode(asset).write(
            to: stagingDirectory.appendingPathComponent(
                Self.assetManifestFileName
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
