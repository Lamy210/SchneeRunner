import AppKit
import SchneeRunnerCore

@MainActor
final class CharacterLibraryController {
    private let store: CharacterAssetStore
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

        store = CharacterAssetStore(
            rootDirectory: applicationSupportDirectory
                .appendingPathComponent("SchneeRunner", isDirectory: true)
                .appendingPathComponent("Characters", isDirectory: true),
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
        }
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

    func recentAssets(limit: Int = 8) throws -> [StoredCharacterAsset] {
        let assets = try store.listAssets()
        return Array(assets.prefix(max(limit, 0)))
    }

    func frames(for asset: StoredCharacterAsset) throws -> [NSImage] {
        try frames(
            from: store.sourceURL(for: asset),
            kind: asset.kind
        )
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
