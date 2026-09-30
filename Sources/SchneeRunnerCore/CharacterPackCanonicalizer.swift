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
            let canonicalClip = try copyResolvedClip(
                state: clip.state,
                kind: clip.kind,
                sourceURL: sourceURL,
                destinationPackageURL: destinationPackageURL,
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

    func copyResolvedClip(
        state: CharacterState,
        kind: CharacterPackClipKind,
        sourceURL: URL,
        destinationPackageURL: URL,
        copiedBytes: inout Int
    ) throws -> CharacterPackClip {
        let clipDirectory = destinationPackageURL
            .appendingPathComponent("clips", isDirectory: true)
            .appendingPathComponent(
                state.rawValue,
                isDirectory: true
            )
        try fileManager.createDirectory(
            at: clipDirectory,
            withIntermediateDirectories: true
        )

        return try copyClip(
            CharacterPackClip(
                state: state,
                kind: kind,
                path: ""
            ),
            sourceURL: sourceURL,
            destinationDirectory: clipDirectory,
            copiedBytes: &copiedBytes
        )
    }

    private func copyClip(
        _ clip: CharacterPackClip,
        sourceURL: URL,
        destinationDirectory: URL,
        copiedBytes: inout Int
    ) throws -> CharacterPackClip {
        switch clip.kind {
        case .singleImage, .spriteSheet4x2:
            try copyPNGSource(
                clip,
                sourceURL: sourceURL,
                destinationDirectory: destinationDirectory,
                copiedBytes: &copiedBytes
            )
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

    private func copyPNGSource(
        _ clip: CharacterPackClip,
        sourceURL: URL,
        destinationDirectory: URL,
        copiedBytes: inout Int
    ) throws -> CharacterPackClip {
        let destinationURL = destinationDirectory
            .appendingPathComponent("source.png")
        try accountAndCopyFile(
            sourceURL,
            destinationURL: destinationURL,
            copiedBytes: &copiedBytes
        )

        return CharacterPackClip(
            state: clip.state,
            kind: clip.kind,
            path: "clips/\(clip.state.rawValue)/source.png"
        )
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
        let sourceSize = try validatedFileSize(sourceURL)
        try validateAggregateSize(
            adding: sourceSize,
            copiedBytes: copiedBytes
        )

        try fileManager.copyItem(
            at: sourceURL,
            to: destinationURL
        )

        let copiedSize = try validatedFileSize(destinationURL)
        try validateAggregateSize(
            adding: copiedSize,
            copiedBytes: copiedBytes
        )
        copiedBytes += copiedSize
    }

    private func validatedFileSize(_ url: URL) throws -> Int {
        let values = try url.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackStoreError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw CharacterPackStoreError.invalidAssetDirectory(url)
        }
        guard let fileSize = values.fileSize else {
            throw CharacterPackStoreError.fileSizeUnavailable(url)
        }

        return fileSize
    }

    private func validateAggregateSize(
        adding fileSize: Int,
        copiedBytes: Int
    ) throws {
        guard
            fileSize <= maximumPackageBytes,
            copiedBytes <= maximumPackageBytes - fileSize
        else {
            throw CharacterPackStoreError.packageTooLarge(
                actual: copiedBytes + fileSize,
                maximum: maximumPackageBytes
            )
        }
    }
}
