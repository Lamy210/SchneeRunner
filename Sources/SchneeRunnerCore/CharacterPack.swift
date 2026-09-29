import Foundation

public enum CharacterPackClipKind: String, Codable, Equatable, Sendable {
    case gif
    case pngSequence
}

public struct CharacterPackClip: Codable, Equatable, Sendable {
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
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let name: String
    public let defaultState: CharacterState
    public let clips: [CharacterPackClip]

    public init(
        formatVersion: Int = Self.currentFormatVersion,
        name: String,
        defaultState: CharacterState,
        clips: [CharacterPackClip]
    ) {
        self.formatVersion = formatVersion
        self.name = name
        self.defaultState = defaultState
        self.clips = clips
    }
}
