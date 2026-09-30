import Foundation

public struct CharacterPackBuildClip: Equatable, Sendable {
    public let state: CharacterState
    public let kind: CharacterPackClipKind
    public let sourceURL: URL

    public init(
        state: CharacterState,
        kind: CharacterPackClipKind,
        sourceURL: URL
    ) {
        self.state = state
        self.kind = kind
        self.sourceURL = sourceURL
    }
}

public struct CharacterPackBuildRequest: Equatable, Sendable {
    public let name: String
    public let defaultState: CharacterState
    public let clips: [CharacterPackBuildClip]

    public init(
        name: String,
        defaultState: CharacterState,
        clips: [CharacterPackBuildClip]
    ) {
        self.name = name
        self.defaultState = defaultState
        self.clips = clips
    }
}

public enum CharacterPackBuilderError: Error, Equatable, LocalizedError {
    case invalidDestinationExtension(String)
    case destinationExists(URL)
    case invalidDestinationDirectory(URL)
    case symbolicLinkNotAllowed(URL)

    public var errorDescription: String? {
        switch self {
        case let .invalidDestinationExtension(value):
            "Character Pack builds must use the .schneerunner extension. Received .\(value)."
        case let .destinationExists(url):
            "Character Pack destination already exists: \(url.lastPathComponent)."
        case let .invalidDestinationDirectory(url):
            "Character Pack destination directory is invalid: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed for the Character Pack destination: \(url.lastPathComponent)."
        }
    }
}

public struct CharacterPackBuilder {
    public let maximumPackageBytes: Int

    private let fileManager: FileManager
    private let loader: CharacterPackLoader
    private let canonicalizer: CharacterPackCanonicalizer
    private let encoder: JSONEncoder

    public init(
        maximumPackageBytes: Int = 128 * 1024 * 1024,
        fileManager: FileManager = .default,
        loader: CharacterPackLoader = .init()
    ) {
        let maximumPackageBytes = max(maximumPackageBytes, 1)

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
        self.encoder = encoder
    }

    public func build(
        _ request: CharacterPackBuildRequest,
        at destinationURL: URL
    ) throws {
        try validateDestination(destinationURL)

        let provisionalManifest = provisionalManifest(for: request)
        try loader.validateManifest(provisionalManifest)

        let stagingURL = stagingURL(for: destinationURL)
        try? fileManager.removeItem(at: stagingURL)
        try fileManager.createDirectory(
            at: stagingURL,
            withIntermediateDirectories: false
        )

        do {
            let manifest = try canonicalManifest(
                for: request,
                destinationPackageURL: stagingURL
            )
            try writeManifest(
                manifest,
                packageURL: stagingURL
            )
            _ = try loader.load(from: stagingURL)
            try fileManager.moveItem(
                at: stagingURL,
                to: destinationURL
            )
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            throw error
        }
    }

    private func provisionalManifest(
        for request: CharacterPackBuildRequest
    ) -> CharacterPackManifest {
        CharacterPackManifest(
            name: request.name,
            defaultState: request.defaultState,
            clips: request.clips.map { clip in
                CharacterPackClip(
                    state: clip.state,
                    kind: clip.kind,
                    path: "source"
                )
            }
        )
    }

    private func canonicalManifest(
        for request: CharacterPackBuildRequest,
        destinationPackageURL: URL
    ) throws -> CharacterPackManifest {
        let orderedClips = CharacterState.allCases.compactMap { state in
            request.clips.first { $0.state == state }
        }
        var copiedBytes = 0
        var canonicalClips: [CharacterPackClip] = []

        for clip in orderedClips {
            let canonicalClip = try canonicalizer.copyResolvedClip(
                state: clip.state,
                kind: clip.kind,
                sourceURL: clip.sourceURL,
                destinationPackageURL: destinationPackageURL,
                copiedBytes: &copiedBytes
            )
            canonicalClips.append(canonicalClip)
        }

        return CharacterPackManifest(
            name: request.name,
            defaultState: request.defaultState,
            clips: canonicalClips
        )
    }

    private func writeManifest(
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

    private func validateDestination(_ destinationURL: URL) throws {
        let fileExtension = destinationURL.pathExtension.lowercased()
        guard fileExtension == "schneerunner" else {
            throw CharacterPackBuilderError.invalidDestinationExtension(
                fileExtension
            )
        }
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw CharacterPackBuilderError.destinationExists(
                destinationURL
            )
        }

        let directory = destinationURL.deletingLastPathComponent()
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackBuilderError.symbolicLinkNotAllowed(
                directory
            )
        }
        guard values.isDirectory == true else {
            throw CharacterPackBuilderError.invalidDestinationDirectory(
                directory
            )
        }
    }

    private func stagingURL(for destinationURL: URL) -> URL {
        destinationURL
            .deletingLastPathComponent()
            .appendingPathComponent(
                ".schneerunner-build-\(UUID().uuidString).schneerunner",
                isDirectory: true
            )
    }
}
