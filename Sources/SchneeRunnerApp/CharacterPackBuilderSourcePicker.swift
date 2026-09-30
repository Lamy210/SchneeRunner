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
                contentType: .png
            )
        case .gif:
            chooseFile(
                title: "Choose GIF for \(state.displayName)",
                contentType: .gif
            )
        case .pngSequence:
            chooseDirectory(
                title: "Choose PNG Sequence for \(state.displayName)"
            )
        }
    }

    private func chooseFile(
        title: String,
        contentType: UTType
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Choose"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [contentType]

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
