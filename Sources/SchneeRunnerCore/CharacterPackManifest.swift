import Foundation

public enum CharacterPackAnimationKind: String, Codable, Equatable, Sendable {
    case singleImage
    case spriteSheet4x2
    case pngSequence
    case gif
}

public struct CharacterPackAnimationEntry: Codable, Equatable, Sendable {
    public let state: CharacterState
    public let kind: CharacterPackAnimationKind
    public let path: String

    public init(
        state: CharacterState,
        kind: CharacterPackAnimationKind,
        path: String
    ) {
        self.state = state
        self.kind = kind
        self.path = path
    }
}

public struct CharacterPackManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let name: String
    public let defaultState: CharacterState
    public let animations: [CharacterPackAnimationEntry]

    public init(
        schemaVersion: Int,
        name: String,
        defaultState: CharacterState,
        animations: [CharacterPackAnimationEntry]
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.defaultState = defaultState
        self.animations = animations
    }
}

public struct CharacterPackPolicy: Equatable, Sendable {
    public let maximumManifestBytes: Int
    public let maximumNameLength: Int
    public let maximumAnimationCount: Int
    public let maximumLoadedPixelCount: Int

    public init(
        maximumManifestBytes: Int = 64 * 1024,
        maximumNameLength: Int = 80,
        maximumAnimationCount: Int = CharacterState.allCases.count,
        maximumLoadedPixelCount: Int = 32_000_000
    ) {
        self.maximumManifestBytes = max(maximumManifestBytes, 1)
        self.maximumNameLength = max(maximumNameLength, 1)
        self.maximumAnimationCount = max(maximumAnimationCount, 1)
        self.maximumLoadedPixelCount = max(maximumLoadedPixelCount, 1)
    }
}

public struct LoadedCharacterPack {
    public let manifest: CharacterPackManifest
    public let animations: CharacterAnimationLibrary

    public init(
        manifest: CharacterPackManifest,
        animations: CharacterAnimationLibrary
    ) {
        self.manifest = manifest
        self.animations = animations
    }
}

public enum CharacterPackLoaderError: Error, Equatable, LocalizedError {
    case packNotFound(URL)
    case packIsNotDirectory(URL)
    case symbolicLinkNotAllowed(URL)
    case manifestMissing
    case manifestIsNotRegularFile
    case manifestTooLarge(actual: Int, maximum: Int)
    case invalidManifest
    case unsupportedSchema(actual: Int, expected: Int)
    case invalidName
    case noAnimations
    case tooManyAnimations(actual: Int, maximum: Int)
    case duplicateState(CharacterState)
    case defaultStateMissing(CharacterState)
    case invalidRelativePath(String)
    case resourceNotFound(String)
    case expectedFile(String)
    case expectedDirectory(String)
    case loadedPixelCountTooLarge(actual: Int, maximum: Int)

    public var errorDescription: String? {
        switch self {
        case let .packNotFound(url):
            "Character pack was not found: \(url.lastPathComponent)."
        case let .packIsNotDirectory(url):
            "Character pack is not a directory: \(url.lastPathComponent)."
        case let .symbolicLinkNotAllowed(url):
            "Symbolic links are not allowed in character packs: \(url.lastPathComponent)."
        case .manifestMissing:
            "Character pack is missing manifest.json."
        case .manifestIsNotRegularFile:
            "Character pack manifest.json must be a regular file."
        case let .manifestTooLarge(actual, maximum):
            "Character pack manifest is \(actual) bytes, exceeding the \(maximum)-byte limit."
        case .invalidManifest:
            "Character pack manifest.json could not be decoded."
        case let .unsupportedSchema(actual, expected):
            "Character pack schema \(actual) is unsupported; expected \(expected)."
        case .invalidName:
            "Character pack name must be non-empty and within the configured length limit."
        case .noAnimations:
            "Character pack must contain at least one animation."
        case let .tooManyAnimations(actual, maximum):
            "Character pack defines \(actual) animations, exceeding the \(maximum)-animation limit."
        case let .duplicateState(state):
            "Character pack defines the \(state.rawValue) state more than once."
        case let .defaultStateMissing(state):
            "Character pack default state \(state.rawValue) does not have an animation."
        case let .invalidRelativePath(path):
            "Character pack resource path is invalid: \(path)."
        case let .resourceNotFound(path):
            "Character pack resource was not found: \(path)."
        case let .expectedFile(path):
            "Character pack resource must be a regular file: \(path)."
        case let .expectedDirectory(path):
            "Character pack resource must be a directory: \(path)."
        case let .loadedPixelCountTooLarge(actual, maximum):
            "Character pack uses \(actual) loaded frame pixels, exceeding the \(maximum)-pixel limit."
        }
    }
}
