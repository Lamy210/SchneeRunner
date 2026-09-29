import AppKit
import SchneeRunnerCore

@MainActor
final class StatusMenuController: NSObject {
    let menu = NSMenu()

    var onLoadSingleImage: (() -> Void)?
    var onLoadSpriteSheet: (() -> Void)?
    var onLoadPNGSequence: (() -> Void)?
    var onLoadGIF: (() -> Void)?
    var onLoadRecentCharacter: ((UUID) -> Void)?
    var onToggleCPUAdaptiveSpeed: (() -> Void)?
    var onManualSpeed: ((Double) -> Void)?
    var onQuit: (() -> Void)?

    private let cpuUsageItem = NSMenuItem(
        title: "CPU: sampling…",
        action: nil,
        keyEquivalent: ""
    )
    private let adaptiveSpeedItem = NSMenuItem(
        title: "CPU Adaptive Speed",
        action: nil,
        keyEquivalent: ""
    )
    private let recentCharactersMenu = NSMenu(title: "Recent Characters")

    override init() {
        super.init()
        buildMenu()
    }

    func setCPUStatus(_ title: String) {
        cpuUsageItem.title = title
    }

    func setAdaptiveSpeedEnabled(_ isEnabled: Bool) {
        adaptiveSpeedItem.state = isEnabled ? .on : .off
    }

    func setRecentCharacters(_ assets: [StoredCharacterAsset]) {
        recentCharactersMenu.removeAllItems()

        guard !assets.isEmpty else {
            addDisabledRecentItem(title: "No saved characters")
            return
        }

        for asset in assets {
            let item = NSMenuItem(
                title: recentCharacterTitle(for: asset),
                action: #selector(loadRecentCharacter(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = asset.id.uuidString
            recentCharactersMenu.addItem(item)
        }
    }

    func setRecentCharactersUnavailable() {
        recentCharactersMenu.removeAllItems()
        addDisabledRecentItem(title: "Character library unavailable")
    }

    private func buildMenu() {
        addImportItems()
        addRecentCharactersItem()
        menu.addItem(.separator())
        addCPUItems()
        addManualSpeedItem()
        menu.addItem(.separator())
        addQuitItem()
    }

    private func addImportItems() {
        let singleImageItem = NSMenuItem(
            title: "Load Single Image…",
            action: #selector(loadSingleImage),
            keyEquivalent: "i"
        )
        singleImageItem.target = self
        menu.addItem(singleImageItem)

        let spriteSheetItem = NSMenuItem(
            title: "Load 4x2 Sprite Sheet…",
            action: #selector(loadSpriteSheet),
            keyEquivalent: "o"
        )
        spriteSheetItem.target = self
        menu.addItem(spriteSheetItem)

        let sequenceItem = NSMenuItem(
            title: "Load PNG Sequence…",
            action: #selector(loadPNGSequence),
            keyEquivalent: ""
        )
        sequenceItem.target = self
        menu.addItem(sequenceItem)

        let gifItem = NSMenuItem(
            title: "Load GIF…",
            action: #selector(loadGIF),
            keyEquivalent: ""
        )
        gifItem.target = self
        menu.addItem(gifItem)
    }

    private func addRecentCharactersItem() {
        let item = NSMenuItem(
            title: "Recent Characters",
            action: nil,
            keyEquivalent: ""
        )
        item.submenu = recentCharactersMenu
        menu.addItem(item)
    }

    private func addCPUItems() {
        cpuUsageItem.isEnabled = false
        menu.addItem(cpuUsageItem)

        adaptiveSpeedItem.target = self
        adaptiveSpeedItem.action = #selector(toggleCPUAdaptiveSpeed)
        adaptiveSpeedItem.state = .on
        menu.addItem(adaptiveSpeedItem)
    }

    private func addManualSpeedItem() {
        let speedMenu = NSMenu(title: "Playback Speed")
        let speeds = [
            (framesPerSecond: 6, title: "0.5×"),
            (framesPerSecond: 8, title: "0.67×"),
            (framesPerSecond: 12, title: "1×"),
            (framesPerSecond: 18, title: "1.5×"),
            (framesPerSecond: 24, title: "2×")
        ]

        for speed in speeds {
            let item = NSMenuItem(
                title: speed.title,
                action: #selector(changeAnimationSpeed(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = speed.framesPerSecond
            speedMenu.addItem(item)
        }

        let rootItem = NSMenuItem(
            title: "Playback Speed",
            action: nil,
            keyEquivalent: ""
        )
        rootItem.submenu = speedMenu
        menu.addItem(rootItem)
    }

    private func addQuitItem() {
        let item = NSMenuItem(
            title: "Quit SchneeRunner",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        item.target = self
        menu.addItem(item)
    }

    private func recentCharacterTitle(
        for asset: StoredCharacterAsset
    ) -> String {
        let mode = switch asset.kind {
        case .singleImage:
            "Single Image"
        case .spriteSheet4x2:
            "4x2 Sprite"
        case .pngSequence:
            "PNG Sequence"
        case .gif:
            "GIF"
        }

        return "\(asset.displayName) · \(mode)"
    }

    private func addDisabledRecentItem(title: String) {
        let item = NSMenuItem(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        recentCharactersMenu.addItem(item)
    }

    @objc
    private func loadSingleImage() {
        onLoadSingleImage?()
    }

    @objc
    private func loadSpriteSheet() {
        onLoadSpriteSheet?()
    }

    @objc
    private func loadPNGSequence() {
        onLoadPNGSequence?()
    }

    @objc
    private func loadGIF() {
        onLoadGIF?()
    }

    @objc
    private func loadRecentCharacter(_ sender: NSMenuItem) {
        guard
            let rawID = sender.representedObject as? String,
            let id = UUID(uuidString: rawID)
        else {
            return
        }

        onLoadRecentCharacter?(id)
    }

    @objc
    private func toggleCPUAdaptiveSpeed() {
        onToggleCPUAdaptiveSpeed?()
    }

    @objc
    private func changeAnimationSpeed(_ sender: NSMenuItem) {
        onManualSpeed?(Double(sender.tag))
    }

    @objc
    private func quitApplication() {
        onQuit?()
    }
}
