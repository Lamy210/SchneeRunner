import Foundation
import SchneeRunnerCore

struct StartupCharacterLoadResult {
    let library: CharacterAnimationLibrary?
    let asset: StoredCharacterAsset?
    let unavailableAssetID: UUID?
}

@MainActor
final class StartupCharacterLoader {
    private let characterLibrary: CharacterLibraryController

    init(characterLibrary: CharacterLibraryController) {
        self.characterLibrary = characterLibrary
    }

    func load(resourceRoot: URL?) -> StartupCharacterLoadResult {
        var unavailableAssetID: UUID?

        do {
            if let asset = try characterLibrary.lastSelectedAsset() {
                do {
                    return try StartupCharacterLoadResult(
                        library: characterLibrary.library(for: asset),
                        asset: asset,
                        unavailableAssetID: nil
                    )
                } catch {
                    unavailableAssetID = asset.id
                    characterLibrary.clearLastSelection()
                }
            }
        } catch {
            characterLibrary.clearLastSelection()
        }

        let frameURLs = resolvedBuiltInFrameURLs(resourceRoot: resourceRoot)
        guard frameURLs.count == 4 else {
            return StartupCharacterLoadResult(
                library: nil,
                asset: nil,
                unavailableAssetID: unavailableAssetID
            )
        }

        do {
            let frames = try characterLibrary.frames(
                fromPNGSequence: frameURLs
            )
            let animation = try LoadedAnimation.uniform(frames: frames)
            return StartupCharacterLoadResult(
                library: CharacterAnimationLibrary.single(animation: animation),
                asset: nil,
                unavailableAssetID: unavailableAssetID
            )
        } catch {
            return StartupCharacterLoadResult(
                library: nil,
                asset: nil,
                unavailableAssetID: unavailableAssetID
            )
        }
    }

    private func resolvedBuiltInFrameURLs(resourceRoot: URL?) -> [URL] {
        if let resourceRoot {
            let explicitURLs = BuiltInCharacterResources.yukihanaLamyWalkCycle(
                resourceRoot: resourceRoot
            )
            if explicitURLs.count == 4,
               explicitURLs.allSatisfy({
                   FileManager.default.isReadableFile(atPath: $0.path)
               }) {
                return explicitURLs
            }
        }

        return BuiltInCharacterResources.yukihanaLamyWalkCycle(
            bundle: BuiltInCharacterResources.runtimeBundle()
        )
    }
}
