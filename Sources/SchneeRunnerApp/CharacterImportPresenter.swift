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

    func chooseAPNG(title: String) -> URL? {
        var contentTypes: [UTType] = [.png]
        if let apngType = UTType(filenameExtension: "apng") {
            contentTypes.append(apngType)
        }

        return chooseFile(
            title: title,
            contentTypes: contentTypes
        )
    }

    func chooseWebP(title: String) -> URL? {
        chooseFile(
            title: title,
            contentType: .webP
        )
    }

    func chooseCharacterPack(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Load"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    func chooseCharacterPackBuildDestination(
        suggestedName: String
    ) -> URL? {
        chooseCharacterPackDestination(
            title: "Build Character Pack",
            prompt: "Build",
            suggestedName: suggestedName
        )
    }

    func chooseCharacterPackExportDestination(
        suggestedName: String
    ) -> URL? {
        chooseCharacterPackDestination(
            title: "Export Character Pack",
            prompt: "Export",
            suggestedName: suggestedName
        )
    }

    func presentBuildSuccess(_ url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Character Pack built"
        alert.informativeText = url.path
        alert.runModal()
    }

    func presentBuildError(_ error: Error) {
        presentWarning(
            title: "Could not build character pack",
            error: error
        )
    }

    func presentExportError(_ error: Error) {
        presentWarning(
            title: "Could not export character pack",
            error: error
        )
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

    private func chooseCharacterPackDestination(
        title: String,
        prompt: String,
        suggestedName: String
    ) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.prompt = prompt
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = characterPackFileName(
            suggestedName
        )

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    private func characterPackFileName(
        _ suggestedName: String
    ) -> String {
        let sanitizedName = suggestedName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        return "\(sanitizedName).schneerunner"
    }

    private func chooseFile(
        title: String,
        contentType: UTType
    ) -> URL? {
        chooseFile(
            title: title,
            contentTypes: [contentType]
        )
    }

    private func chooseFile(
        title: String,
        contentTypes: [UTType]
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Load"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = contentTypes

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
