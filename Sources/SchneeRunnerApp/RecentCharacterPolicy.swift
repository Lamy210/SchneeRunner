import SchneeRunnerCore

enum RecentCharacterPolicy {
    static func availableAssets(
        _ assets: [StoredCharacterAsset],
        excluding unavailableAssetIDs: Set<UUID>
    ) -> [StoredCharacterAsset] {
        assets.filter { !unavailableAssetIDs.contains($0.id) }
    }
}
