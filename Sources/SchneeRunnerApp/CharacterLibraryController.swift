import AppKit
import SchneeRunnerCore

@MainActor
final class CharacterLibraryController {
    private let store: CharacterAssetStore
    private let sequenceStore: PNGSequenceAssetStore
    private let gifStore: GIFAssetStore
    private let packStore: CharacterPackStore
    private let selectionStore: CharacterSelectionStore

    init(
        fileManager: FileManager = .default,
        selectionStore: CharacterSelectionStore = .init()
    ) {
        self.selectionStore = selectionStore
        let applicationSupportDirectory = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        let rootDirectory = applicationSupportDirectory
            .appendingPathComponent("SchneeRunner", isDirectory: true)
            .appendingPathComponent("Characters", isDirectory: true)

        store = CharacterAssetStore(
            rootDirectory: rootDirectory,
            fileManager: fileManager
        )
        sequenceStore = PNGSequenceAssetStore(
            rootDirectory: rootDirectory,
            fileManager: fileManager
        )
        gifStore = GIFAssetStore(
            rootDirectory: rootDirectory,
            fileManager: fileManager
        )
        packStore = CharacterPackStore(
            rootDirectory: rootDirectory,
            fileManager: fileManager
        )
    }

    func frames(
        from sourceURL: URL,
        kind: CharacterAssetKind
    ) throws -> [NSImage] {
        switch kind {
        case .singleImage:
            try ProceduralImageFrameGenerator().frames(from: sourceURL)
        case .spriteSheet4x2:
            try SpriteSheetLoader(
                grid: SpriteSheetGrid(columns: 4, rows: 2)
            ).loadFrames(from: sourceURL)
        case .pngSequence:
            throw CharacterAssetStoreError.sequenceRequiresMultipleSources
        case .gif:
            throw CharacterAssetStoreError.gifRequiresDedicatedStore
        case .characterPack:
            throw CharacterAssetStoreError.characterPackRequiresDedicatedStore
        }
    }

    func frames(fromPNGSequence sourceURLs: [URL]) throws -> [NSImage] {
        try PNGSequenceLoader().frames(from: sourceURLs)
    }

    func animation(fromGIF sourceURL: URL) throws -> LoadedAnimation {
        try GIFAnimationLoader().load(from: sourceURL)
    }

    func library(fromCharacterPack sourceURL: URL) throws -> CharacterAnimationLibrary {
        try CharacterPackLoader().load(from: sourceURL)
    }

    func persist(
        sourceURL: URL,
        kind: CharacterAssetKind
    ) throws -> StoredCharacterAsset {
        try store.importAsset(
            from: sourceURL,
            kind: kind
        )
    }

    func persistPNGSequence(
        sourceURLs: [URL]
    ) throws -> StoredCharacterAsset {
        try sequenceStore.importSequence(from: sourceURLs)
    }

    func persistGIF(
        sourceURL: URL
    ) throws -> StoredCharacterAsset {
        try gifStore.importGIF(from: sourceURL)
    }

    func persistCharacterPack(
        sourceURL: URL
    ) throws -> StoredCharacterAsset {
        try packStore.importPack(from: sourceURL)
    }

    func recentAssets(limit: Int = 8) throws -> [StoredCharacterAsset] {
        let assets = try store.listAssets()
        return Array(assets.prefix(max(limit, 0)))
    }

    func frames(for asset: StoredCharacterAsset) throws -> [NSImage] {
        switch asset.kind {
        case .singleImage, .spriteSheet4x2:
            let sourceURL = try store.sourceURL(for: asset)
            return try frames(
                from: sourceURL,
                kind: asset.kind
            )
        case .pngSequence:
            let sourceURLs = try sequenceStore.sourceURLs(for: asset)
            return try PNGSequenceLoader().frames(
                from: sourceURLs
            )
        case .gif:
            throw CharacterAssetStoreError.gifRequiresDedicatedStore
        case .characterPack:
            throw CharacterAssetStoreError.characterPackRequiresDedicatedStore
        }
    }

    func animation(
        for asset: StoredCharacterAsset
    ) throws -> LoadedAnimation {
        switch asset.kind {
        case .gif:
            let sourceURL = try gifStore.sourceURL(for: asset)
            return try GIFAnimationLoader().load(from: sourceURL)
        case .singleImage, .spriteSheet4x2, .pngSequence:
            return try LoadedAnimation.uniform(
                frames: frames(for: asset)
            )
        case .characterPack:
            throw CharacterAssetStoreError.characterPackRequiresDedicatedStore
        }
    }

    func library(
        for asset: StoredCharacterAsset
    ) throws -> CharacterAnimationLibrary {
        switch asset.kind {
        case .characterPack:
            try packStore.library(for: asset)
        case .singleImage, .spriteSheet4x2, .pngSequence, .gif:
            try CharacterAnimationLibrary.single(
                animation: animation(for: asset)
            )
        }
    }

    func asset(id: UUID) throws -> StoredCharacterAsset {
        try store.asset(id: id)
    }

    func rememberSelection(_ asset: StoredCharacterAsset) {
        selectionStore.save(id: asset.id)
    }

    func lastSelectedAsset() throws -> StoredCharacterAsset? {
        guard let id = selectionStore.selectedCharacterID() else {
            return nil
        }

        return try store.asset(id: id)
    }

    func clearLastSelection() {
        selectionStore.clear()
    }
}
