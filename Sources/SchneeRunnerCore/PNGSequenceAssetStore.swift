import Foundation

public enum PNGSequenceAssetStoreError: Error, Equatable, LocalizedError {
    case wrongAssetKind(CharacterAssetKind)
    case sequenceDirectoryMissing(UUID)
    case invalidSequenceDirectory(URL)
    case symbolicLinkNotAllowed(URL)
    case sourceIsNotRegularFile(URL)
    case unsupportedFileType(String)

    public var errorDescription: String? {
        switch self {
        case let .wrongAssetKind(kind):
            "Expected PNG sequence asset, received \(kind.rawValue)."
        case let .sequenceDirectoryMissing(id):
            "PNG sequence frames for \(id.uuidString) were not found."
        case let .invalidSequenceDirectory(url):
            "PNG sequence frame directory is invalid: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed in PNG sequences: \(url.lastPathComponent)."
        case let .sourceIsNotRegularFile(url):
            "PNG sequence frame is not a regular file: \(url.lastPathComponent)."
        case let .unsupportedFileType(fileExtension):
            "PNG sequence frames must use .png files, received .\(fileExtension)."
        }
    }
}

public struct PNGSequenceAssetStore {
    public let rootDirectory: URL

    private static let manifestFileName = "manifest.json"
    private static let framesDirectoryName = "frames"

    private let fileManager: FileManager
    private let loader: PNGSequenceLoader
    private let encoder: JSONEncoder

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        loader: PNGSequenceLoader = .init()
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.loader = loader

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func importSequence(
        from sourceURLs: [URL],
        createdAt: Date = Date()
    ) throws -> StoredCharacterAsset {
        let orderedURLs = try loader.validatedOrderedURLs(sourceURLs)
        try fileManager.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )

        let id = UUID()
        let asset = StoredCharacterAsset(
            schemaVersion: CharacterAssetStore.currentSchemaVersion,
            id: id,
            displayName: displayName(for: orderedURLs),
            kind: .pngSequence,
            createdAt: createdAt
        )

        try persist(
            asset: asset,
            orderedURLs: orderedURLs
        )
        return asset
    }

    public func sourceURLs(
        for asset: StoredCharacterAsset
    ) throws -> [URL] {
        guard asset.kind == .pngSequence else {
            throw PNGSequenceAssetStoreError.wrongAssetKind(asset.kind)
        }

        let directory = rootDirectory
            .appendingPathComponent(asset.id.uuidString, isDirectory: true)
            .appendingPathComponent(Self.framesDirectoryName, isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else {
            throw PNGSequenceAssetStoreError.sequenceDirectoryMissing(asset.id)
        }

        try validateDirectory(directory)
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )

        try urls.forEach(validateFrameFile)
        return try loader.validatedOrderedURLs(urls)
    }

    private func persist(
        asset: StoredCharacterAsset,
        orderedURLs: [URL]
    ) throws {
        let stagingDirectory = rootDirectory
            .appendingPathComponent(
                ".staging-\(asset.id.uuidString)",
                isDirectory: true
            )
        let finalDirectory = rootDirectory
            .appendingPathComponent(asset.id.uuidString, isDirectory: true)

        try? fileManager.removeItem(at: stagingDirectory)
        try fileManager.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: false
        )

        do {
            try writeSequence(
                asset: asset,
                sourceURLs: orderedURLs,
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

    private func writeSequence(
        asset: StoredCharacterAsset,
        sourceURLs: [URL],
        stagingDirectory: URL
    ) throws {
        let framesDirectory = stagingDirectory.appendingPathComponent(
            Self.framesDirectoryName,
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: framesDirectory,
            withIntermediateDirectories: false
        )

        for (index, sourceURL) in sourceURLs.enumerated() {
            let fileName = String(
                format: "%04d.png",
                index + 1
            )
            try fileManager.copyItem(
                at: sourceURL,
                to: framesDirectory.appendingPathComponent(fileName)
            )
        }

        try encoder.encode(asset).write(
            to: stagingDirectory.appendingPathComponent(Self.manifestFileName),
            options: .atomic
        )
    }

    private func displayName(for orderedURLs: [URL]) -> String {
        let firstName = orderedURLs[0]
            .deletingPathExtension()
            .lastPathComponent
        return "\(firstName) Sequence"
    }

    private func validateDirectory(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw PNGSequenceAssetStoreError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw PNGSequenceAssetStoreError.invalidSequenceDirectory(url)
        }
    }

    private func validateFrameFile(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw PNGSequenceAssetStoreError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw PNGSequenceAssetStoreError.sourceIsNotRegularFile(url)
        }

        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "png" else {
            throw PNGSequenceAssetStoreError.unsupportedFileType(fileExtension)
        }
    }
}
