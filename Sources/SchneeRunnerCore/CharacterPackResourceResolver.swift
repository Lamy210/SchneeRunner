import Foundation

struct CharacterPackResourceResolver {
    let maximumManifestBytes: Int

    private let fileManager: FileManager

    init(
        maximumManifestBytes: Int,
        fileManager: FileManager
    ) {
        self.maximumManifestBytes = maximumManifestBytes
        self.fileManager = fileManager
    }

    func manifestData(
        from packageURL: URL
    ) throws -> Data {
        try validatePackageDirectory(packageURL)

        let manifestURL = packageURL.appendingPathComponent(
            CharacterPackLoader.manifestFileName
        )
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw CharacterPackLoaderError.manifestMissing(manifestURL)
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
            throw CharacterPackLoaderError.invalidManifest(manifestURL)
        }
        guard let fileSize = values.fileSize else {
            throw CharacterPackLoaderError.manifestSizeUnavailable(
                manifestURL
            )
        }
        guard fileSize <= maximumManifestBytes else {
            throw CharacterPackLoaderError.manifestTooLarge(
                actual: fileSize,
                maximum: maximumManifestBytes
            )
        }

        return try boundedManifestData(
            from: manifestURL
        )
    }

    func resolveClipURL(
        path: String,
        packageURL: URL
    ) throws -> URL {
        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )

        guard
            !path.isEmpty,
            !path.hasPrefix("/"),
            !path.contains("\\"),
            components.allSatisfy({
                !$0.isEmpty && $0 != "." && $0 != ".."
            })
        else {
            throw CharacterPackLoaderError.unsafeRelativePath(path)
        }

        var url = packageURL
        for (index, component) in components.enumerated() {
            url.appendPathComponent(String(component))

            guard fileManager.fileExists(atPath: url.path) else {
                throw CharacterPackLoaderError.clipMissing(path)
            }

            let values = try url.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard values.isSymbolicLink != true else {
                throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
            }

            if index < components.count - 1, values.isDirectory != true {
                throw CharacterPackLoaderError.unsafeRelativePath(path)
            }
        }

        return url
    }

    func validateDirectory(
        _ url: URL,
        kind: CharacterPackClipKind
    ) throws {
        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.wrongClipResourceType(
                path: url.lastPathComponent,
                kind: kind
            )
        }
    }

    func validateRegularFile(
        _ url: URL,
        kind: CharacterPackClipKind
    ) throws {
        let values = try url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isRegularFile == true else {
            throw CharacterPackLoaderError.wrongClipResourceType(
                path: url.lastPathComponent,
                kind: kind
            )
        }
    }

    private func validatePackageDirectory(_ url: URL) throws {
        let fileExtension = url.pathExtension.lowercased()
        guard fileExtension == "schneerunner" else {
            throw CharacterPackLoaderError.invalidPackageExtension(
                fileExtension
            )
        }

        let values = try url.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(url)
        }
        guard values.isDirectory == true else {
            throw CharacterPackLoaderError.packageIsNotDirectory(url)
        }
    }

    private func boundedManifestData(
        from manifestURL: URL
    ) throws -> Data {
        let handle = try FileHandle(forReadingFrom: manifestURL)
        defer {
            try? handle.close()
        }

        let data = try handle.read(
            upToCount: maximumManifestBytes + 1
        ) ?? Data()
        guard data.count <= maximumManifestBytes else {
            throw CharacterPackLoaderError.manifestTooLarge(
                actual: data.count,
                maximum: maximumManifestBytes
            )
        }

        return data
    }
}
