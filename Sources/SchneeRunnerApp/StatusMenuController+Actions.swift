import AppKit

@MainActor
extension StatusMenuController {
    @objc
    func loadSingleImage() {
        onLoadSingleImage?()
    }

    @objc
    func loadSpriteSheet() {
        onLoadSpriteSheet?()
    }

    @objc
    func loadPNGSequence() {
        onLoadPNGSequence?()
    }

    @objc
    func loadGIF() {
        onLoadGIF?()
    }

    @objc
    func loadAPNG() {
        onLoadAPNG?()
    }

    @objc
    func loadWebP() {
        onLoadWebP?()
    }

    @objc
    func loadCharacterPack() {
        onLoadCharacterPack?()
    }

    @objc
    func buildCharacterPack() {
        onBuildCharacterPack?()
    }

    @objc
    func exportCharacterPack() {
        onExportCharacterPack?()
    }

    @objc
    func loadRecentCharacter(_ sender: NSMenuItem) {
        guard
            let rawID = sender.representedObject as? String,
            let id = UUID(uuidString: rawID)
        else {
            return
        }

        onLoadRecentCharacter?(id)
    }

    @objc
    func toggleCPUAdaptiveSpeed() {
        onToggleCPUAdaptiveSpeed?()
    }

    @objc
    func changeAnimationSpeed(_ sender: NSMenuItem) {
        onManualSpeed?(Double(sender.tag))
    }

    @objc
    func quitApplication() {
        onQuit?()
    }
}
