import AppKit
import Foundation

public struct CharacterPackLoader {
    public static let currentSchemaVersion = 1

    public let policy: CharacterPackPolicy

    private let fileManager: FileManager

    public init(
        policy: CharacterPackPolicy = .init(),
        fileManager: FileManager = .default
    ) {
        self.policy = policy
        self.fileManager = fileManager
    }

    public func load(from packURL: URL) throws -> LoadedCharacterPack {
        try validatePackDirectory(packURL)

        let manifest = try loadManifest(from: packURL)
        try validateManifest(manifest)

        var animations: [CharacterState: LoadedAnimation] = [:]
        var loadedPixelCount = 0

        for entry in manifest.animations {
            let animation = try loadAnimation(
                entry,
                packURL: packURL
            )
            try addLoadedPixels(
                animation,
                total: &loadedPixelCount
            )
            animations[entry.state] = animation
        }

        let library = try CharacterAnimationLibrary(
            animations: animations,
            defaultState: manifest.defaultState
        )
        return LoadedCharacterPack(
            manifest: manifest,
            animations: library
        )
    }

    private func validatePackDirectory(_ url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw CharacterPackLoaderError.packNotFound(url)
        }

        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.packIsNotDirectory(url)
        }
    }

    private func loadManifest(
        from packURL: URL
    ) throws -> CharacterPackManifest {
        let manifestURL = packURL.appendingPathComponent(
            "manifest.json",
            isDirectory: false
        )
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CharacterPackLoaderError.manifestMissing
        }

        let values = try manifestURL.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(
                manifestURL
            )
        }
        guard values.isRegularFile == true else {
            throw CharacterPackLoaderError.manifestIsNotRegularFile
        }
        guard let fileSize = values.fileSize else {
            throw CharacterPackLoaderError.manifestIsNotRegularFile
        }
        guard fileSize <= policy.maximumManifestBytes else {
            throw CharacterPackLoaderError.manifestTooLarge(
                actual: fileSize,
                maximum: policy.maximumManifestBytes
            )
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            return try JSONDecoder().decode(
                CharacterPackManifest.self,
                from: data
            )
        } catch {
            throw CharacterPackLoaderError.invalidManifest
        }
    }

    private func validateManifest(
        _ manifest: CharacterPackManifest
    ) throws {
        guard manifest.schemaVersion == Self.currentSchemaVersion else {
            throw CharacterPackLoaderError.unsupportedSchema(
                actual: manifest.schemaVersion,
                expected: Self.currentSchemaVersion
            )
        }

        let name = manifest.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard
            !name.isEmpty,
            name.count <= policy.maximumNameLength,
            name.rangeOfCharacter(from: .controlCharacters) == nil
        else {
            throw CharacterPackLoaderError.invalidName
        }

        guard !manifest.animations.isEmpty else {
            throw CharacterPackLoaderError.noAnimations
        }
        guard manifest.animations.count <= policy.maximumAnimationCount else {
            throw CharacterPackLoaderError.tooManyAnimations(
                actual: manifest.animations.count,
                maximum: policy.maximumAnimationCount
            )
        }

        var states = Set<CharacterState>()
        for entry in manifest.animations {
            guard states.insert(entry.state).inserted else {
                throw CharacterPackLoaderError.duplicateState(
                    entry.state
                )
            }
        }

        guard states.contains(manifest.defaultState) else {
            throw CharacterPackLoaderError.defaultStateMissing(
                manifest.defaultState
            )
        }
    }

    private func loadAnimation(
        _ entry: CharacterPackAnimationEntry,
        packURL: URL
    ) throws -> LoadedAnimation {
        let resourceURL = try validatedResourceURL(
            relativePath: entry.path,
            packURL: packURL
        )

        switch entry.kind {
        case .singleImage:
            try requireFile(resourceURL, relativePath: entry.path)
            let frames = try ProceduralImageFrameGenerator().frames(
                from: resourceURL
            )
            return try LoadedAnimation.uniform(frames: frames)

        case .spriteSheet4x2:
            try requireFile(resourceURL, relativePath: entry.path)
            let frames = try SpriteSheetLoader(
                grid: SpriteSheetGrid(columns: 4, rows: 2)
            ).loadFrames(from: resourceURL)
            return try LoadedAnimation.uniform(frames: frames)

        case .pngSequence:
            try requireDirectory(
                resourceURL,
                relativePath: entry.path
            )
            let frameURLs = try pngFrameURLs(
                in: resourceURL
            )
            let frames = try PNGSequenceLoader().frames(
                from: frameURLs
            )
            return try LoadedAnimation.uniform(frames: frames)

        case .gif:
            try requireFile(resourceURL, relativePath: entry.path)
            return try GIFAnimationLoader().load(
                from: resourceURL
            )
        }
    }

    private func validatedResourceURL(
        relativePath: String,
        packURL: URL
    ) throws -> URL {
        let components = relativePath.split(
            separator: "/",
            omittingEmptySubsequences: false
        ).map(String.init)

        guard
            !relativePath.isEmpty,
            !relativePath.hasPrefix("/"),
            !components.contains(where: {
                $0.isEmpty || $0 == "." || $0 == ".."
            })
        else {
            throw CharacterPackLoaderError.invalidRelativePath(
                relativePath
            )
        }

        let standardizedPackURL = packURL.standardizedFileURL
        var currentURL = standardizedPackURL

        for component in components {
            currentURL.appendPathComponent(component)

            guard fileManager.fileExists(atPath: currentURL.path) else {
                throw CharacterPackLoaderError.resourceNotFound(
                    relativePath
                )
            }

            let values = try currentURL.resourceValues(
                forKeys: [.isSymbolicLinkKey]
            )
            guard values.isSymbolicLink != true else {
                throw CharacterPackLoaderError.symbolicLinkNotAllowed(
                    currentURL
                )
            }
        }

        let expectedPrefix = standardizedPackURL.path + "/"
        guard currentURL.standardizedFileURL.path.hasPrefix(expectedPrefix) else {
            throw CharacterPackLoaderError.invalidRelativePath(
                relativePath
            )
        }

        return currentURL
    }

    private func requireFile(
        _ url: URL,
        relativePath: String
    ) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey]
        )
        guard values.isRegularFile == true else {
            throw CharacterPackLoaderError.expectedFile(
                relativePath
            )
        }
    }

    private func requireDirectory(
        _ url: URL,
        relativePath: String
    ) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey]
        )
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.expectedDirectory(
                relativePath
            )
        }
    }

    private func pngFrameURLs(
        in directoryURL: URL
    ) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles]
        )
        .filter {
            $0.pathExtension.lowercased() == "png"
        }
    }

    private func addLoadedPixels(
        _ animation: LoadedAnimation,
        total: inout Int
    ) throws {
        let animationPixels = animation.frames.reduce(into: 0) {
            partialResult,
            image in

            let pixels = pixelCount(for: image)
            let sum = partialResult.addingReportingOverflow(pixels)
            partialResult = sum.overflow ? Int.max : sum.partialValue
        }

        let sum = total.addingReportingOverflow(animationPixels)
        let newTotal = sum.overflow ? Int.max : sum.partialValue
        guard newTotal <= policy.maximumLoadedPixelCount else {
            throw CharacterPackLoaderError.loadedPixelCountTooLarge(
                actual: newTotal,
                maximum: policy.maximumLoadedPixelCount
            )
        }

        total = newTotal
    }

    private func pixelCount(for image: NSImage) -> Int {
        let representation = image.representations.max {
            lhs,
            rhs in

            lhs.pixelsWide * lhs.pixelsHigh
                < rhs.pixelsWide * rhs.pixelsHigh
        }
        let width = max(
            representation?.pixelsWide
                ?? Int(image.size.width.rounded(.up)),
            1
        )
        let height = max(
            representation?.pixelsHigh
                ?? Int(image.size.height.rounded(.up)),
            1
        )
        let product = width.multipliedReportingOverflow(
            by: height
        )
        return product.overflow ? Int.max : product.partialValue
    }
}
