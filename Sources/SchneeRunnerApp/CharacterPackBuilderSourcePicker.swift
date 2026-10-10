import AppKit
import SchneeRunnerCore
import UniformTypeIdentifiers

@MainActor
final class CharacterPackBuilderSourcePicker {
    private let localization: AppLocalization

    init(localization: AppLocalization = .current) {
        self.localization = localization
    }

    func chooseSource(
        for state: CharacterState,
        kind: CharacterPackClipKind
    ) -> URL? {
        let stateName = localization.characterState(state)

        switch kind {
        case .singleImage, .spriteSheet4x2:
            chooseFile(
                title: localization.string(
                    "characterPack.picker.pngTitle",
                    arguments: stateName
                ),
                contentTypes: [.png]
            )
        case .gif:
            chooseFile(
                title: localization.string(
                    "characterPack.picker.gifTitle",
                    arguments: stateName
                ),
                contentTypes: [.gif]
            )
        case .apng:
            chooseFile(
                title: localization.string(
                    "characterPack.picker.apngTitle",
                    arguments: stateName
                ),
                contentTypes: apngContentTypes
            )
        case .webP:
            chooseFile(
                title: localization.string(
                    "characterPack.picker.webPTitle",
                    arguments: stateName
                ),
                contentTypes: [.webP]
            )
        case .pngSequence:
            chooseDirectory(
                title: localization.string(
                    "characterPack.picker.pngSequenceTitle",
                    arguments: stateName
                )
            )
        }
    }

    private var apngContentTypes: [UTType] {
        var types: [UTType] = [.png]
        if let apngType = UTType(filenameExtension: "apng") {
            types.append(apngType)
        }

        return types
    }

    private func chooseFile(
        title: String,
        contentTypes: [UTType]
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = localization.string("action.choose")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = contentTypes

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    private func chooseDirectory(
        title: String
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = localization.string("action.choose")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
