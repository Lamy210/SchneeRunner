import Foundation

struct CharacterPackCanonicalizer {
    let maximumPackageBytes: Int

    private let fileManager: FileManager
    private let loader: CharacterPackLoader

    init(
        maximumPackageBytes: Int,
        fileManager: FileManager,
        loader: CharacterPackLoader
    ) {
        self.maximumPackageBytes = maximumPackageBytes
        self.fileManager = fileManager
        self.loader = loader
    }

    func copyReferencedClips(
        _ manifest: CharacterPackManifest,
        sourcePackageURL: URL,
        destinationPackageURL: URL
    ) throws -> CharacterPackManifest {
        var copiedBytes = 0
        var canonicalClips: [CharacterPackClip] = []

        for clip in manifest.clips {
            let sourceURL = try loader.resolveClipURL(
                path: clip.path,
                packageURL: sourcePackageURL
            )
            let clipDirectory = destinationPackageURL
                .appendingPathComponent("clips", isDirectory: true)
                .appendingPathComponent(
                    clip.state.rawValue,
                    isDirectory: true
                )
            try fileManager.createDirectory(
                at: clipDirectory,
                withIntermediateDirectories: true
            )

            let canonicalClip = try copyClip(
                clip,
                sourceURL: sourceURL,
                destinationDirectory: clipDirectory,
                copiedBytes: &copiedBytes
            )
            canonicalClips.append(canonicalClip)
        }

        return CharacterPackManifest(
            name: manifest.name,
            defaultState: manifest.defaultState,
            clips: canonicalClips
        )
    }

    private func copyClip(
        _ clip: CharacterPackClip,
        sourceURL: URL,
        destinationDirectory: URL,
        copiedBytes: inout Int
    ) throws -> CharacterPackClip {
        switch clip.kind {
        case .gif:
            try copyGIF(
                clip,
                sourceURL: sourceURL,
                destinationDirectory: destinationDirectory,
                copiedBytes: &copiedBytes
            )
        case .pngSequence:
            try copyPNGSequence(
                clip,
                sourceURL: sourceURL,
                destinationDirectory: destinationDirectory,
                copiedBytes: &copiedBytes
            )
        }
    }

    private func copyGIF(
        _ clip: CharacterPackClip,
        sourceURL: URL,
        destinationDirectory: URL,
        copiedBytes: inout Int
    ) throws -> CharacterPackClip {
        let destinationURL = destinationDirectory
            .appendingPathComponent("source.gif")
        try accountAndCopyFile(
            sourceURL,
            destinationURL: destinationURL,
            copiedBytes: &copiedBytes
        )

        return CharacterPackClip(
            state: clip.state,
            kind: .gif,
            path: "clips/\(clip.state.rawValue)/source.gif"
        )
    }

    private func copyPNGSequence(
        _ clip: CharacterPackClip,
        sourceURL: URL,
        destinationDirectory: URL,
        copiedBytes: inout Int
    ) throws -> CharacterPackClip {
        let frameURLs = try orderedSequenceURLs(
            at: sourceURL
        )
        let framesDirectory = destinationDirectory
            .appendingPathComponent("frames", isDirectory: true)
        try fileManager.createDirectory(
            at: framesDirectory,
            withIntermediateDirectories: false
        )

        for (index, frameURL) in frameURLs.enumerated() {
            let fileName = String(
                format: "%04d.png",
                index + 1
            )
            try accountAndCopyFile(
                frameURL,
                destinationURL: framesDirectory
                    .appendingPathComponent(fileName),
                copiedBytes: &copiedBytes
            )
        }

        return CharacterPackClip(
            state: clip.state,
            kind: .pngSequence,
            path: "clips/\(clip.state.rawValue)/frames"
        )
    }

    private func orderedSequenceURLs(
        at directory: URL
    ) throws -> [URL] {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles]
        )
        return try PNGSequenceLoader()
            .validatedOrderedURLs(urls)
    }

    private func accountAndCopyFile(
        _ sourceURL: URL,
        destinationURL: URL,
        copiedBytes: inout Int
    ) throws {
        let values = try sourceURL.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackStoreError.symbolicLinkNotAllowed(sourceURL)
        }
        guard values.isRegularFile == true else {
            throw CharacterPackStoreError.invalidAssetDirectory(sourceURL)
        }
        guard let fileSize = values.fileSize else {
            throw CharacterPackStoreError.fileSizeUnavailable(
                sourceURL
            )
        }
        guard
            fileSize <= maximumPackageBytes,
            copiedBytes <= maximumPackageBytes - fileSize
        else {
            throw CharacterPackStoreError.packageTooLarge(
                actual: copiedBytes + fileSize,
                maximum: maximumPackageBytes
            )
        }

        try fileManager.copyItem(
            at: sourceURL,
            to: destinationURL
        )
        copiedBytes += fileSize
    }
}
