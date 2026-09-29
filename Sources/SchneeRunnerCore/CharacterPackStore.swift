import Foundation

public enum CharacterPackStoreError: Error, Equatable, LocalizedError {
    case wrongAssetKind(CharacterAssetKind)
    case assetDirectoryMissing(UUID)
    case invalidAssetDirectory(URL)
    case symbolicLinkNotAllowed(URL)
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
    private let encoder: JSONEncoder

    public init(
        rootDirectory: URL,
        maximumPackageBytes: Int = 128 * 1024 * 1024,
        fileManager: FileManager = .default,
        loader: CharacterPackLoader = .init()
    ) {
        self.rootDirectory = rootDirectory
        self.maximumPackageBytes = max(maximumPackageBytes, 1)
        self.fileManager = fileManager
        self.loader = loader

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
            let packageURL = stagingDirectory.appendingPathComponent(
                Self.packageDirectoryName,
                isDirectory: true
            )
            try fileManager.createDirectory(
                at: packageURL,
                withIntermediateDirectories: false
            )

            let canonicalManifest = try copyReferencedClips(
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
            try fileManager.moveItem(
                at: stagingDirectory,
                to: finalDirectory
            )
        } catch {
            try? fileManager.removeItem(at: stagingDirectory)
            throw error
        }
    }

    private func copyReferencedClips(
        _ manifest: CharacterPackManifest,
        sourcePackageURL: URL,
        destinationPackageURL: URL
    ) throws -> CharacterPackManifest {
        var copiedBytes = 0
        var canonicalClips: [CharacterPackClip] = []

        for clip in manifest.clips {
            let sourceURL = try loader.resolveClipURL(
                path: clip.path,
                packageURL: sourcePackageURL
            )
            let clipDirectory = destinationPackageURL
                .appendingPathComponent("clips", isDirectory: true)
                .appendingPathComponent(
                    clip.state.rawValue,
                    isDirectory: true
                )
            try fileManager.createDirectory(
                at: clipDirectory,
                withIntermediateDirectories: true
            )

            let canonicalClip = try copyClip(
                clip,
                sourceURL: sourceURL,
                destinationDirectory: clipDirectory,
                copiedBytes: &copiedBytes
            )
            canonicalClips.append(canonicalClip)
        }

        return CharacterPackManifest(
            name: manifest.name,
            defaultState: manifest.defaultState,
            clips: canonicalClips
        )
    }

    private func copyClip(
        _ clip: CharacterPackClip,
        sourceURL: URL,
        destinationDirectory: URL,
        copiedBytes: inout Int
    ) throws -> CharacterPackClip {
        switch clip.kind {
        case .gif:
            let destinationURL = destinationDirectory
                .appendingPathComponent("source.gif")
            try accountAndCopyFile(
                sourceURL,
                destinationURL: destinationURL,
                copiedBytes: &copiedBytes
            )
            return CharacterPackClip(
                state: clip.state,
                kind: .gif,
                path: "clips/\(clip.state.rawValue)/source.gif"
            )

        case .pngSequence:
            let frameURLs = try orderedSequenceURLs(
                at: sourceURL
            )
            let framesDirectory = destinationDirectory
                .appendingPathComponent("frames", isDirectory: true)
            try fileManager.createDirectory(
                at: framesDirectory,
                withIntermediateDirectories: false
            )

            for (index, frameURL) in frameURLs.enumerated() {
                let fileName = String(
                    format: "%04d.png",
                    index + 1
                )
                try accountAndCopyFile(
                    frameURL,
                    destinationURL: framesDirectory
                        .appendingPathComponent(fileName),
                    copiedBytes: &copiedBytes
                )
            }

            return CharacterPackClip(
                state: clip.state,
                kind: .pngSequence,
                path: "clips/\(clip.state.rawValue)/frames"
            )
        }
    }

    private func orderedSequenceURLs(
        at directory: URL
    ) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles]
        )
        return try PNGSequenceLoader()
            .validatedOrderedURLs(urls)
    }

    private func accountAndCopyFile(
        _ sourceURL: URL,
        destinationURL: URL,
        copiedBytes: inout Int
    ) throws {
        let values = try sourceURL.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackStoreError.symbolicLinkNotAllowed(sourceURL)
        }
        guard values.isRegularFile == true else {
            throw CharacterPackStoreError.invalidAssetDirectory(sourceURL)
        }

        let fileSize = values.fileSize ?? 0
        guard copiedBytes <= maximumPackageBytes - fileSize else {
            throw CharacterPackStoreError.packageTooLarge(
                actual: copiedBytes + fileSize,
                maximum: maximumPackageBytes
            )
        }

        try fileManager.copyItem(
            at: sourceURL,
            to: destinationURL
        )
        copiedBytes += fileSize
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
