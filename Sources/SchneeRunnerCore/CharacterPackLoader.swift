import AppKit
import Foundation

public enum CharacterPackLoaderError: Error, Equatable, LocalizedError {
    case invalidPackageExtension(String)
    case packageIsNotDirectory(URL)
    case symbolicLinkNotAllowed(URL)
    case manifestMissing(URL)
    case manifestSizeUnavailable(URL)
    case manifestTooLarge(actual: Int, maximum: Int)
    case invalidManifest(URL)
    case unsupportedFormatVersion(Int)
    case invalidName
    case emptyClips
    case tooManyClips(actual: Int, maximum: Int)
    case duplicateState(CharacterState)
    case defaultStateMissing(CharacterState)
    case unsafeRelativePath(String)
    case clipMissing(String)
    case wrongClipResourceType(path: String, kind: CharacterPackClipKind)

    public var errorDescription: String? {
        switch self {
        case let .invalidPackageExtension(value):
            "Character pack must use the .schneerunner extension. Received .\(value)."
        case let .packageIsNotDirectory(url):
            "Character pack is not a directory: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed in character packs: \(url.lastPathComponent)."
        case let .manifestMissing(url):
            "Character pack manifest is missing: \(url.lastPathComponent)."
        case let .manifestSizeUnavailable(url):
            "Could not determine character pack manifest size: \(url.lastPathComponent)."
        case let .manifestTooLarge(actual, maximum):
            "Character pack manifest is \(actual) bytes, exceeding the \(maximum)-byte limit."
        case let .invalidManifest(url):
            "Character pack manifest is invalid: \(url.lastPathComponent)."
        case let .unsupportedFormatVersion(version):
            "Character pack format version \(version) is not supported."
        case .invalidName:
            "Character pack name must contain 1–80 visible characters."
        case .emptyClips:
            "Character pack must contain at least one animation clip."
        case let .tooManyClips(actual, maximum):
            "Character pack contains \(actual) clips, exceeding the \(maximum)-clip limit."
        case let .duplicateState(state):
            "Character pack defines \(state.rawValue) more than once."
        case let .defaultStateMissing(state):
            "Character pack default state \(state.rawValue) has no clip."
        case let .unsafeRelativePath(path):
            "Character pack clip path is unsafe: \(path)."
        case let .clipMissing(path):
            "Character pack clip is missing: \(path)."
        case let .wrongClipResourceType(path, kind):
            "Character pack clip \(path) is not valid for kind \(kind.rawValue)."
        }
    }
}

public struct CharacterPackLoader {
    public static let manifestFileName = "character.json"

    public let maximumManifestBytes: Int
    public let maximumClipCount: Int

    private let fileManager: FileManager
    private let decoder: JSONDecoder

    public init(
        maximumManifestBytes: Int = 64 * 1024,
        maximumClipCount: Int = CharacterState.allCases.count,
        fileManager: FileManager = .default
    ) {
        self.maximumManifestBytes = max(maximumManifestBytes, 1)
        self.maximumClipCount = max(maximumClipCount, 1)
        self.fileManager = fileManager
        decoder = JSONDecoder()
    }

    public func load(
        from packageURL: URL
    ) throws -> CharacterAnimationLibrary {
        let manifest = try validatedManifest(
            from: packageURL
        )
        var animations: [CharacterState: LoadedAnimation] = [:]

        for clip in manifest.clips {
            animations[clip.state] = try loadClip(
                clip,
                packageURL: packageURL
            )
        }

        return try CharacterAnimationLibrary(
            animations: animations,
            defaultState: manifest.defaultState
        )
    }

    public func validatedManifest(
        from packageURL: URL
    ) throws -> CharacterPackManifest {
        try validatePackageDirectory(packageURL)

        let manifestURL = packageURL.appendingPathComponent(
            Self.manifestFileName
        )
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CharacterPackLoaderError.manifestMissing(manifestURL)
        }
        let values = try manifestURL.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(
                manifestURL
            )
        }
        guard values.isRegularFile == true else {
            throw CharacterPackLoaderError.invalidManifest(manifestURL)
        }
        guard let fileSize = values.fileSize else {
            throw CharacterPackLoaderError.manifestSizeUnavailable(
                manifestURL
            )
        }
        guard fileSize <= maximumManifestBytes else {
            throw CharacterPackLoaderError.manifestTooLarge(
                actual: fileSize,
                maximum: maximumManifestBytes
            )
        }

        let manifest: CharacterPackManifest
        do {
            manifest = try decoder.decode(
                CharacterPackManifest.self,
                from: boundedManifestData(from: manifestURL)
            )
        } catch let error as CharacterPackLoaderError {
            throw error
        } catch {
            throw CharacterPackLoaderError.invalidManifest(manifestURL)
        }

        try validateManifest(manifest)
        for clip in manifest.clips {
            _ = try resolveClipURL(
                path: clip.path,
                packageURL: packageURL
            )
        }

        return manifest
    }

    private func boundedManifestData(
        from manifestURL: URL
    ) throws -> Data {
        let handle = try FileHandle(forReadingFrom: manifestURL)
        defer {
            try? handle.close()
        }

        let data = try handle.read(
            upToCount: maximumManifestBytes + 1
        ) ?? Data()
        guard data.count <= maximumManifestBytes else {
            throw CharacterPackLoaderError.manifestTooLarge(
                actual: data.count,
                maximum: maximumManifestBytes
            )
        }

        return data
    }

    func resolveClipURL(
        path: String,
        packageURL: URL
    ) throws -> URL {
        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )

        guard
            !path.isEmpty,
            !path.hasPrefix("/"),
            !path.contains("\\"),
            components.allSatisfy({
                !$0.isEmpty && $0 != "." && $0 != ".."
            })
        else {
            throw CharacterPackLoaderError.unsafeRelativePath(path)
        }

        var url = packageURL
        for (index, component) in components.enumerated() {
            url.appendPathComponent(String(component))

            guard fileManager.fileExists(atPath: url.path) else {
                throw CharacterPackLoaderError.clipMissing(path)
            }

            let values = try url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard values.isSymbolicLink != true else {
                throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
            }

            if index < components.count - 1, values.isDirectory != true {
                throw CharacterPackLoaderError.unsafeRelativePath(path)
            }
        }

        return url
    }

    private func validateManifest(
        _ manifest: CharacterPackManifest
    ) throws {
        guard manifest.formatVersion == CharacterPackManifest.currentFormatVersion else {
            throw CharacterPackLoaderError.unsupportedFormatVersion(
                manifest.formatVersion
            )
        }

        let name = manifest.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let containsControlCharacter = name.unicodeScalars.contains {
            CharacterSet.controlCharacters.contains($0)
        }
        guard
            !name.isEmpty,
            name == manifest.name,
            name.count <= 80,
            !containsControlCharacter
        else {
            throw CharacterPackLoaderError.invalidName
        }

        guard !manifest.clips.isEmpty else {
            throw CharacterPackLoaderError.emptyClips
        }
        guard manifest.clips.count <= maximumClipCount else {
            throw CharacterPackLoaderError.tooManyClips(
                actual: manifest.clips.count,
                maximum: maximumClipCount
            )
        }

        var states = Set<CharacterState>()
        for clip in manifest.clips {
            guard states.insert(clip.state).inserted else {
                throw CharacterPackLoaderError.duplicateState(
                    clip.state
                )
            }
        }

        guard states.contains(manifest.defaultState) else {
            throw CharacterPackLoaderError.defaultStateMissing(
                manifest.defaultState
            )
        }
    }

    private func loadClip(
        _ clip: CharacterPackClip,
        packageURL: URL
    ) throws -> LoadedAnimation {
        let url = try resolveClipURL(
            path: clip.path,
            packageURL: packageURL
        )

        switch clip.kind {
        case .singleImage:
            try validateRegularNonSymlinkFile(
                url,
                kind: clip.kind
            )
            let frames = try ProceduralImageFrameGenerator()
                .frames(from: url)
            return try LoadedAnimation.uniform(
                frames: frames
            )

        case .spriteSheet4x2:
            try validateRegularNonSymlinkFile(
                url,
                kind: clip.kind
            )
            let frames = try SpriteSheetLoader(
                grid: SpriteSheetGrid(columns: 4, rows: 2)
            ).loadFrames(from: url)
            return try LoadedAnimation.uniform(
                frames: frames
            )

        case .gif:
            try validateRegularNonSymlinkFile(
                url,
                kind: clip.kind
            )
            return try GIFAnimationLoader().load(from: url)

        case .pngSequence:
            try validateDirectory(url)
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey
                ],
                options: [.skipsHiddenFiles]
            )
            let frames = try PNGSequenceLoader().frames(
                from: urls
            )
            return try LoadedAnimation.uniform(
                frames: frames
            )
        }
    }

    private func validatePackageDirectory(_ url: URL) throws {
        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "schneerunner" else {
            throw CharacterPackLoaderError.invalidPackageExtension(
                fileExtension
            )
        }

        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.packageIsNotDirectory(url)
        }
    }

    private func validateDirectory(_ url: URL) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.wrongClipResourceType(
                path: url.lastPathComponent,
                kind: .pngSequence
            )
        }
    }

    private func validateRegularNonSymlinkFile(
        _ url: URL,
        kind: CharacterPackClipKind
    ) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw CharacterPackLoaderError.wrongClipResourceType(
                path: url.lastPathComponent,
                kind: kind
            )
        }
    }
}
