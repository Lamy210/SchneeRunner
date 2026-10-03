import Foundation
import SchneeRunnerCore

enum RecentCharacterPolicy {
    static func availableAssets(
        _ assets: [StoredCharacterAsset],
        excluding unavailableAssetIDs: Set<UUID>,
        limit: Int = .max
    ) -> [StoredCharacterAsset] {
        let availableAssets = assets.filter {
            !unavailableAssetIDs.contains($0.id)
        }
        return Array(availableAssets.prefix(max(limit, 0)))
    }
}
