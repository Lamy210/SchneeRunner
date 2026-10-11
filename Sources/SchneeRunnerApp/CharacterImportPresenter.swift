import AppKit
import UniformTypeIdentifiers

@MainActor
final class CharacterImportPresenter {
    private let localization: AppLocalization

    init(localization: AppLocalization = .current) {
        self.localization = localization
    }

    func choosePNG(title: String) -> URL? {
        chooseFile(
            title: title,
            contentType: .png
        )
    }

    func choosePNGs(title: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = localization.string("import.prompt.load")
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
        panel.prompt = localization.string("import.prompt.load")
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
            title: localization.string("characterPack.builder.title"),
            prompt: localization.string("action.build"),
            suggestedName: suggestedName
        )
    }

    func chooseCharacterPackExportDestination(
        suggestedName: String
    ) -> URL? {
        chooseCharacterPackDestination(
            title: localization.string("characterPack.export.title"),
            prompt: localization.string("action.export"),
            suggestedName: suggestedName
        )
    }

    func presentBuildSuccess(_ url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = localization.string("characterPack.build.success")
        alert.informativeText = url.path
        alert.runModal()
    }

    func presentBuildError(_ error: Error) {
        presentWarning(
            title: localization.string("characterPack.build.error"),
            error: error
        )
    }

    func presentExportError(_ error: Error) {
        presentWarning(
            title: localization.string("characterPack.export.error"),
            error: error
        )
    }

    func presentLoadError(_ error: Error) {
        presentWarning(
            title: localization.string("import.error.load"),
            error: error
        )
    }

    func presentPersistenceWarning(_ error: Error) {
        presentWarning(
            title: localization.string("import.warning.persistence"),
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
        panel.nameFieldStringValue = CharacterPackFileNamePolicy.fileName(
            for: suggestedName
        )

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
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
        panel.prompt = localization.string("import.prompt.load")
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
