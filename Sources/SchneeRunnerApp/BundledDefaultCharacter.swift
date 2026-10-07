import Foundation

enum BundledDefaultCharacterError: Error, Equatable {
    case missingFrame(String)
}

enum BundledDefaultCharacter {
    static let frameFileNames = [
        "lamy-walk-01.png",
        "lamy-walk-02.png",
        "lamy-walk-03.png",
        "lamy-walk-04.png",
    ]

    static func frameURLs(resourceRoot: URL) throws -> [URL] {
        let directory = resourceRoot
            .appendingPathComponent("DefaultCharacter", isDirectory: true)

        return try frameFileNames.map { fileName in
            let url = directory.appendingPathComponent(fileName, isDirectory: false)
            guard
                FileManager.default.isReadableFile(atPath: url.path),
                (try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]))
                    .map({ $0.isRegularFile == true && $0.isSymbolicLink != true }) == true
            else {
                throw BundledDefaultCharacterError.missingFrame(fileName)
            }
            return url
        }
    }
}
