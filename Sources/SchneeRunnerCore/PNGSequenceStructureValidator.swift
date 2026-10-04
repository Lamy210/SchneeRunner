import Foundation

struct PNGSequenceStructureValidator {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func isStructurallyAvailable(
        at framesDirectory: URL
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
