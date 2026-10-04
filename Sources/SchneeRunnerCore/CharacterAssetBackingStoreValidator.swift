import Foundation

public struct CharacterAssetBackingStoreValidator {
    public let rootDirectory: URL

    private let fileManager: FileManager
    private let characterPackLoader: CharacterPackLoader

    public init(
        rootDirectory: URL,
        fileManager: FileManager = .default
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        characterPackLoader = CharacterPackLoader(
            fileManager: fileManager
        )
    }

    public func isStructurallyAvailable(
        _ asset: StoredCharacterAsset
    ) -> Bool {
        let assetDirectory = rootDirectory.appendingPathComponent(
            asset.id.uuidString,
            isDirectory: true
        )
        guard isRegularDirectory(assetDirectory) else {
            return false
        }

        switch asset.kind {
        case .singleImage, .spriteSheet4x2:
            return isRegularFile(
                assetDirectory.appendingPathComponent("source.png")
            )
        case .pngSequence:
            return isSequenceAvailable(
                in: assetDirectory.appendingPathComponent(
                    "frames",
                    isDirectory: true
                )
            )
        case .gif:
            return isRegularFile(
                assetDirectory.appendingPathComponent("source.gif")
            )
        case .apng:
            return isRegularFile(
                assetDirectory.appendingPathComponent("source.png")
            )
        case .webP:
            return isRegularFile(
                assetDirectory.appendingPathComponent("source.webp")
            )
        case .characterPack:
            return isCharacterPackAvailable(in: assetDirectory)
        }
    }

    private func isSequenceAvailable(
        in framesDirectory: URL
    ) -> Bool {
        guard
            isRegularDirectory(framesDirectory),
            let frameURLs = try? fileManager.contentsOfDirectory(
                at: framesDirectory,
                includingPropertiesForKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey
                ],
                options: [.skipsHiddenFiles]
            ),
            frameURLs.count >= 2
        else {
            return false
        }

        return frameURLs.allSatisfy { url in
            url.pathExtension.lowercased() == "png"
                && isRegularFile(url)
        }
    }

    private func isCharacterPackAvailable(
        in assetDirectory: URL
    ) -> Bool {
        let packageDirectory = assetDirectory.appendingPathComponent(
            CharacterPackStore.packageDirectoryName,
            isDirectory: true
        )
        guard isRegularDirectory(packageDirectory) else {
            return false
        }

        return (try? characterPackLoader.validatedManifest(
            from: packageDirectory
        )) != nil
    }

    private func isRegularDirectory(_ url: URL) -> Bool {
        guard
            let values = try? url.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ]
            )
        else {
            return false
        }

        return values.isDirectory == true
            && values.isSymbolicLink != true
    }

    private func isRegularFile(_ url: URL) -> Bool {
        guard
            let values = try? url.resourceValues(
                forKeys: [
                    .isRegularFileKey,
                    .isSymbolicLinkKey
                ]
            )
        else {
            return false
        }

        return values.isRegularFile == true
            && values.isSymbolicLink != true
    }
}
