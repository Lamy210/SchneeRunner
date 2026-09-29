import Foundation

struct CharacterPackResourceResolver {
    private let packURL: URL
    private let fileManager: FileManager

    init(
        packURL: URL,
        fileManager: FileManager
    ) {
        self.packURL = packURL.standardizedFileURL
        self.fileManager = fileManager
    }

    func resolve(
        relativePath: String
    ) throws -> URL {
        let components = try validatedComponents(
            relativePath
        )
        var currentURL = packURL

        for component in components {
            currentURL = currentURL.appendingPathComponent(
                component
            )
            try validateExistingNonSymlink(
                currentURL,
                relativePath: relativePath
            )
        }

        let expectedPrefix = packURL.path + "/"
        guard currentURL.standardizedFileURL.path.hasPrefix(expectedPrefix) else {
            throw CharacterPackLoaderError.invalidRelativePath(
                relativePath
            )
        }

        return currentURL
    }

    func requireFile(
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

    func requireDirectory(
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

    func pngFrameURLs(
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

    private func validatedComponents(
        _ relativePath: String
    ) throws -> [String] {
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

        return components
    }

    private func validateExistingNonSymlink(
        _ url: URL,
        relativePath: String
    ) throws {
        guard fileManager.fileExists(atPath: url.path) else {
            throw CharacterPackLoaderError.resourceNotFound(
                relativePath
            )
        }

        let values = try url.resourceValues(
            forKeys: [.isSymbolicLinkKey]
        )
        guard values.isSymbolicLink != true else {
            throw CharacterPackLoaderError.symbolicLinkNotAllowed(
                url
            )
        }
    }
}
