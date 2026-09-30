import AppKit
import SchneeRunnerCore
import UniformTypeIdentifiers

@MainActor
final class CharacterPackBuilderSourcePicker {
    func chooseSource(
        for state: CharacterState,
        kind: CharacterPackClipKind
    ) -> URL? {
        switch kind {
        case .singleImage, .spriteSheet4x2:
            chooseFile(
                title: "Choose PNG for \(state.displayName)",
                contentTypes: [.png]
            )
        case .gif:
            chooseFile(
                title: "Choose GIF for \(state.displayName)",
                contentTypes: [.gif]
            )
        case .apng:
            chooseFile(
                title: "Choose APNG for \(state.displayName)",
                contentTypes: apngContentTypes
            )
        case .webP:
            chooseFile(
                title: "Choose WebP for \(state.displayName)",
                contentTypes: [.webP]
            )
        case .pngSequence:
            chooseDirectory(
                title: "Choose PNG Sequence for \(state.displayName)"
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
        panel.prompt = "Choose"
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
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }
}
