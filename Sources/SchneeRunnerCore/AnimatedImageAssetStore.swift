import Foundation

public enum AnimatedImageAssetStoreError: Error, Equatable, LocalizedError {
    case wrongAssetKind(CharacterAssetKind)
    case assetDirectoryMissing(UUID)
    case invalidAssetDirectory(URL)
    case symbolicLinkNotAllowed(URL)
    case sourceIsNotRegularFile(URL)

    public var errorDescription: String? {
        switch self {
        case let .wrongAssetKind(kind):
            "Expected APNG or WebP asset, received \(kind.rawValue)."
        case let .assetDirectoryMissing(id):
            "Animated image asset \(id.uuidString) was not found."
        case let .invalidAssetDirectory(url):
            "Animated image asset directory is invalid: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for animated image assets: \(url.lastPathComponent)."
        case let .sourceIsNotRegularFile(url):
            "Animated image source is not a regular file: \(url.lastPathComponent)."
        }
    }
}

public struct AnimatedImageAssetStore {
    public let rootDirectory: URL

    private static let manifestFileName = "manifest.json"

    private let fileManager: FileManager
    private let policy: AnimatedImagePolicy
    private let encoder: JSONEncoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        policy: AnimatedImagePolicy = .init()
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.policy = policy

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func importAnimation(
        from sourceURL: URL,
        format: AnimatedImageFormat,
        createdAt: Date = Date()
    ) throws -> StoredCharacterAsset {
        let loader = loader(for: format)
        _ = try loader.load(from: sourceURL)
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let id = UUID()
        let asset = StoredCharacterAsset(
            schemaVersion: CharacterAssetStore.currentSchemaVersion,
            id: id,
            displayName: sourceURL.deletingPathExtension().lastPathComponent,
            kind: assetKind(for: format),
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
            try writeAsset(
                asset,
                sourceURL: sourceURL,
                format: format,
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

        return asset
    }

    public func sourceURL(
        for asset: StoredCharacterAsset
    ) throws -> URL {
        let format = try format(for: asset.kind)
        let directory = assetDirectory(id: asset.id)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw AnimatedImageAssetStoreError.assetDirectoryMissing(
                asset.id
            )
        }

        try validateDirectory(directory)
        let sourceURL = directory.appendingPathComponent(
            sourceFileName(for: format)
        )
        try validateSourceFile(sourceURL)
        try loader(for: format).validate(url: sourceURL)
        return sourceURL
    }

    private func writeAsset(
        _ asset: StoredCharacterAsset,
        sourceURL: URL,
        format: AnimatedImageFormat,
        stagingDirectory: URL
    ) throws {
        let copiedURL = stagingDirectory.appendingPathComponent(
            sourceFileName(for: format)
        )
        try fileManager.copyItem(
            at: sourceURL,
            to: copiedURL
        )
        _ = try loader(for: format).load(from: copiedURL)

        try encoder.encode(asset).write(
            to: stagingDirectory.appendingPathComponent(
                Self.manifestFileName
            ),
            options: .atomic
        )
    }

    private func loader(
        for format: AnimatedImageFormat
    ) -> AnimatedImageLoader {
        AnimatedImageLoader(
            format: format,
            policy: policy
        )
    }

    private func assetKind(
        for format: AnimatedImageFormat
    ) -> CharacterAssetKind {
        switch format {
        case .apng:
            .apng
        case .webP:
            .webP
        }
    }

    private func format(
        for kind: CharacterAssetKind
    ) throws -> AnimatedImageFormat {
        switch kind {
        case .apng:
            .apng
        case .webP:
            .webP
        case .singleImage,
             .spriteSheet4x2,
             .pngSequence,
             .gif,
             .characterPack:
            throw AnimatedImageAssetStoreError.wrongAssetKind(kind)
        }
    }

    private func sourceFileName(
        for format: AnimatedImageFormat
    ) -> String {
        "source.\(format.canonicalFileExtension)"
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
            throw AnimatedImageAssetStoreError.symbolicLinkNotAllowed(
                url
            )
        }
        guard values.isDirectory == true else {
            throw AnimatedImageAssetStoreError.invalidAssetDirectory(
                url
            )
        }
    }

    private func validateSourceFile(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw AnimatedImageAssetStoreError.symbolicLinkNotAllowed(
                url
            )
        }
        guard values.isRegularFile == true else {
            throw AnimatedImageAssetStoreError.sourceIsNotRegularFile(
                url
            )
        }
    }
}
