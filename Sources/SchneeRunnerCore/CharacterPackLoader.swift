import Foundation

public struct CharacterPackPolicy: Equatable, Sendable {
    public let maximumTotalFileBytes: Int
    public let maximumFileCount: Int
    public let maximumNameLength: Int

    public init(
        maximumTotalFileBytes: Int = 128 * 1024 * 1024,
        maximumFileCount: Int = 650,
        maximumNameLength: Int = 80
    ) {
        self.maximumTotalFileBytes = max(maximumTotalFileBytes, 1)
        self.maximumFileCount = max(maximumFileCount, 1)
        self.maximumNameLength = max(maximumNameLength, 1)
    }
}

public enum CharacterPackLoaderError: Error, Equatable, LocalizedError {
    case invalidPackageExtension(String)
    case sourceIsNotDirectory(URL)
    case symbolicLinkNotAllowed(URL)
    case packageEnumerationFailed(URL)
    case fileSizeUnavailable(URL)
    case tooManyFiles(actual: Int, maximum: Int)
    case packageTooLarge(actual: Int, maximum: Int)
    case manifestMissing(URL)
    case invalidManifest(URL)
    case unsupportedSchemaVersion(Int)
    case invalidName
    case emptyClips
    case tooManyClips(actual: Int, maximum: Int)
    case duplicateState(CharacterState)
    case defaultStateMissing(CharacterState)
    case invalidRelativePath(String)
    case clipPathMissing(String)
    case expectedFile(String)
    case expectedDirectory(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidPackageExtension(fileExtension):
            "Character packs must use .schneerunnerpack, received .\(fileExtension)."
        case let .sourceIsNotDirectory(url):
            "Character pack is not a directory: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed in character packs: \(url.lastPathComponent)."
        case let .packageEnumerationFailed(url):
            "Could not enumerate character pack: \(url.lastPathComponent)."
        case let .fileSizeUnavailable(url):
            "Could not determine file size in character pack: \(url.lastPathComponent)."
        case let .tooManyFiles(actual, maximum):
            "Character pack contains \(actual) files, exceeding the \(maximum)-file limit."
        case let .packageTooLarge(actual, maximum):
            "Character pack uses \(actual) bytes, exceeding the \(maximum)-byte limit."
        case let .manifestMissing(url):
            "Character pack manifest is missing: \(url.lastPathComponent)."
        case let .invalidManifest(url):
            "Character pack manifest is invalid: \(url.lastPathComponent)."
        case let .unsupportedSchemaVersion(version):
            "Character pack schema version \(version) is not supported."
        case .invalidName:
            "Character pack name must contain 1–80 visible characters."
        case .emptyClips:
            "Character packs require at least one animation clip."
        case let .tooManyClips(actual, maximum):
            "Character pack contains \(actual) clips, exceeding the \(maximum)-clip limit."
        case let .duplicateState(state):
            "Character pack defines state \(state.rawValue) more than once."
        case let .defaultStateMissing(state):
            "Character pack default state \(state.rawValue) does not have a clip."
        case let .invalidRelativePath(path):
            "Character pack clip path is unsafe: \(path)."
        case let .clipPathMissing(path):
            "Character pack clip path does not exist: \(path)."
        case let .expectedFile(path):
            "Character pack clip must be a file: \(path)."
        case let .expectedDirectory(path):
            "Character pack clip must be a directory: \(path)."
        }
    }
}

public struct CharacterPackLoader {
    public static let currentSchemaVersion = 1

    private static let packageExtension = "schneerunnerpack"
    private static let manifestFileName = "manifest.json"

    public let policy: CharacterPackPolicy

    private let fileManager: FileManager

    public init(
        policy: CharacterPackPolicy = .init(),
        fileManager: FileManager = .default
    ) {
        self.policy = policy
        self.fileManager = fileManager
    }

    public func load(from packageURL: URL) throws -> LoadedCharacterPack {
        try validatePackageRoot(packageURL)
        try validatePackageResources(packageURL)

        let manifest = try loadManifest(from: packageURL)
        let displayName = try validateManifest(manifest)
        let animations = try loadAnimations(
            manifest: manifest,
            packageURL: packageURL
        )
        let library = try CharacterAnimationLibrary(
            animations: animations,
            defaultState: manifest.defaultState
        )

        return LoadedCharacterPack(
            manifest: manifest,
            displayName: displayName,
            library: library
        )
    }

    private func validatePackageRoot(_ packageURL: URL) throws {
        let fileExtension = packageURL.pathExtension.lowercased()
        guard fileExtension == Self.packageExtension else {
            throw CharacterPackLoaderError.invalidPackageExtension(
                fileExtension
            )
        }

        let values = try packageURL.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(packageURL)
        }
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.sourceIsNotDirectory(packageURL)
        }
    }

    private func validatePackageResources(_ packageURL: URL) throws {
        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .isDirectoryKey,
            .isRegularFileKey,
            .isSymbolicLinkKey
        ]
        guard let enumerator = fileManager.enumerator(
            at: packageURL,
            includingPropertiesForKeys: keys,
            options: []
        ) else {
            throw CharacterPackLoaderError.packageEnumerationFailed(
                packageURL
            )
        }

        var fileCount = 0
        var totalBytes = 0

        while let url = enumerator.nextObject() as? URL {
            let values = try url.resourceValues(
                forKeys: Set(keys)
            )
            if values.isSymbolicLink == true {
                enumerator.skipDescendants()
                throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
            }
            guard values.isRegularFile == true else {
                continue
            }

            guard let fileSize = values.fileSize else {
                throw CharacterPackLoaderError.fileSizeUnavailable(url)
            }
            fileCount += 1
            guard fileCount <= policy.maximumFileCount else {
                throw CharacterPackLoaderError.tooManyFiles(
                    actual: fileCount,
                    maximum: policy.maximumFileCount
                )
            }
            guard totalBytes <= policy.maximumTotalFileBytes - fileSize else {
                throw CharacterPackLoaderError.packageTooLarge(
                    actual: totalBytes + fileSize,
                    maximum: policy.maximumTotalFileBytes
                )
            }
            totalBytes += fileSize
        }
    }

    private func loadManifest(
        from packageURL: URL
    ) throws -> CharacterPackManifest {
        let manifestURL = packageURL.appendingPathComponent(
            Self.manifestFileName
        )
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CharacterPackLoaderError.manifestMissing(manifestURL)
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            return try JSONDecoder().decode(
                CharacterPackManifest.self,
                from: data
            )
        } catch {
            throw CharacterPackLoaderError.invalidManifest(manifestURL)
        }
    }

    private func validateManifest(
        _ manifest: CharacterPackManifest
    ) throws -> String {
        guard manifest.schemaVersion == Self.currentSchemaVersion else {
            throw CharacterPackLoaderError.unsupportedSchemaVersion(
                manifest.schemaVersion
            )
        }

        let displayName = manifest.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            !displayName.isEmpty,
            displayName.count <= policy.maximumNameLength
        else {
            throw CharacterPackLoaderError.invalidName
        }

        guard !manifest.clips.isEmpty else {
            throw CharacterPackLoaderError.emptyClips
        }
        guard manifest.clips.count <= CharacterState.allCases.count else {
            throw CharacterPackLoaderError.tooManyClips(
                actual: manifest.clips.count,
                maximum: CharacterState.allCases.count
            )
        }

        var states = Set<CharacterState>()
        for clip in manifest.clips {
            guard states.insert(clip.state).inserted else {
                throw CharacterPackLoaderError.duplicateState(
                    clip.state
                )
            }
            try validateRelativePath(clip.path)
        }

        guard states.contains(manifest.defaultState) else {
            throw CharacterPackLoaderError.defaultStateMissing(
                manifest.defaultState
            )
        }

        return displayName
    }

    private func validateRelativePath(_ path: String) throws {
        guard
            !path.isEmpty,
            !path.contains("\\"),
            !path.contains(":")
        else {
            throw CharacterPackLoaderError.invalidRelativePath(path)
        }

        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard
            !components.isEmpty,
            components.allSatisfy({
                !$0.isEmpty && $0 != "." && $0 != ".."
            })
        else {
            throw CharacterPackLoaderError.invalidRelativePath(path)
        }
    }

    private func loadAnimations(
        manifest: CharacterPackManifest,
        packageURL: URL
    ) throws -> [CharacterState: LoadedAnimation] {
        var animations: [CharacterState: LoadedAnimation] = [:]

        for clip in manifest.clips {
            let url = packageURL.appendingPathComponent(clip.path)
            guard fileManager.fileExists(atPath: url.path) else {
                throw CharacterPackLoaderError.clipPathMissing(
                    clip.path
                )
            }

            animations[clip.state] = try loadAnimation(
                clip: clip,
                url: url
            )
        }

        return animations
    }

    private func loadAnimation(
        clip: CharacterPackClipManifest,
        url: URL
    ) throws -> LoadedAnimation {
        switch clip.kind {
        case .singleImage:
            try validateFile(url, path: clip.path)
            let frames = try ProceduralImageFrameGenerator()
                .frames(from: url)
            return try LoadedAnimation.uniform(frames: frames)
        case .spriteSheet4x2:
            try validateFile(url, path: clip.path)
            let frames = try SpriteSheetLoader(
                grid: SpriteSheetGrid(columns: 4, rows: 2)
            ).loadFrames(from: url)
            return try LoadedAnimation.uniform(frames: frames)
        case .pngSequence:
            try validateDirectory(url, path: clip.path)
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            let frames = try PNGSequenceLoader().frames(from: urls)
            return try LoadedAnimation.uniform(frames: frames)
        case .gif:
            try validateFile(url, path: clip.path)
            return try GIFAnimationLoader().load(from: url)
        }
    }

    private func validateFile(
        _ url: URL,
        path: String
    ) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw CharacterPackLoaderError.expectedFile(path)
        }
    }

    private func validateDirectory(
        _ url: URL,
        path: String
    ) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.expectedDirectory(path)
        }
    }
}
