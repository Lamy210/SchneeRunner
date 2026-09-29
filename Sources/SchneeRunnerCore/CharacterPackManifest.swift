import Foundation

public enum CharacterPackClipKind: String, Codable, Equatable, Sendable {
    case singleImage
    case spriteSheet4x2
    case pngSequence
    case gif
}

public struct CharacterPackClipManifest: Codable, Equatable, Sendable {
    public let state: CharacterState
    public let kind: CharacterPackClipKind
    public let path: String

    public init(
        state: CharacterState,
        kind: CharacterPackClipKind,
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
    public let clips: [CharacterPackClipManifest]

    public init(
        schemaVersion: Int = 1,
        name: String,
        defaultState: CharacterState,
        clips: [CharacterPackClipManifest]
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.defaultState = defaultState
        self.clips = clips
    }
}

public struct LoadedCharacterPack {
    public let manifest: CharacterPackManifest
    public let displayName: String
    public let library: CharacterAnimationLibrary

    public init(
        manifest: CharacterPackManifest,
        displayName: String,
        library: CharacterAnimationLibrary
    ) {
        self.manifest = manifest
        self.displayName = displayName
        self.library = library
    }
}
