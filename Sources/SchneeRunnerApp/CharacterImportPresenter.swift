import AppKit
import UniformTypeIdentifiers

@MainActor
final class CharacterImportPresenter {
    func choosePNG(title: String) -> URL? {
        chooseFile(
            title: title,
            contentType: .png
        )
    }

    func choosePNGs(title: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Load"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png]

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.urls
    }

    func chooseGIF(title: String) -> URL? {
        chooseFile(
            title: title,
            contentType: .gif
        )
    }

    func chooseCharacterPack(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Load"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func presentLoadError(_ error: Error) {
        presentWarning(
            title: "Could not load animation",
            error: error
        )
    }

    func presentPersistenceWarning(_ error: Error) {
        presentWarning(
            title: "Character is running, but was not saved",
            error: error
        )
    }

    private func chooseFile(
        title: String,
        contentType: UTType
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Load"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [contentType]

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    private func presentWarning(
        title: String,
        error: Error
    ) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
