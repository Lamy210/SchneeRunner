import AppKit
import SchneeRunnerCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let animationController = AnimationController()
    private let cpuMonitor = CPUMonitor()
    private let characterLibrary = CharacterLibraryController()
    private let menuController = StatusMenuController()

    private var statusItem: NSStatusItem?
    private var latestCPUUpdate: CPUMonitor.Update?
    private var isCPUAdaptiveSpeedEnabled = true

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        configureStatusItem()
        configureAnimationCallback()
        configureMenuCallbacks()
        configureCPUMonitor()
        refreshRecentCharactersMenu()
        cpuMonitor.start()
    }

    func applicationWillTerminate(_: Notification) {
        cpuMonitor.stop()
        animationController.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "figure.run",
            accessibilityDescription: "SchneeRunner"
        )
        item.menu = menuController.menu
        statusItem = item
    }

    private func configureAnimationCallback() {
        animationController.onFrame = { [weak self] image in
            self?.statusItem?.button?.image = Self.menuBarImage(from: image)
        }
    }

    private func configureMenuCallbacks() {
        menuController.onLoadSingleImage = { [weak self] in
            self?.loadImportedCharacter(
                kind: .singleImage,
                panelTitle: "Choose an Image"
            )
        }
        menuController.onLoadSpriteSheet = { [weak self] in
            self?.loadImportedCharacter(
                kind: .spriteSheet4x2,
                panelTitle: "Choose a 4x2 Sprite Sheet"
            )
        }
        menuController.onLoadRecentCharacter = { [weak self] id in
            self?.loadRecentCharacter(id: id)
        }
        menuController.onToggleCPUAdaptiveSpeed = { [weak self] in
            self?.toggleCPUAdaptiveSpeed()
        }
        menuController.onManualSpeed = { [weak self] framesPerSecond in
            self?.changeAnimationSpeed(framesPerSecond)
        }
        menuController.onQuit = {
            NSApplication.shared.terminate(nil)
        }
    }

    private func configureCPUMonitor() {
        cpuMonitor.onUpdate = { [weak self] update in
            guard let self else {
                return
            }

            latestCPUUpdate = update

            if isCPUAdaptiveSpeedEnabled {
                animationController.setFramesPerSecond(update.pace.framesPerSecond)
            }

            refreshCPUStatus()
        }

        cpuMonitor.onError = { [weak self] _ in
            self?.latestCPUUpdate = nil
            self?.menuController.setCPUStatus("CPU: unavailable")
        }
    }

    private func refreshCPUStatus() {
        guard let latestCPUUpdate else {
            return
        }

        let percentage = Int((latestCPUUpdate.utilization * 100).rounded())
        let framesPerSecond = Int(animationController.framesPerSecond.rounded())

        if isCPUAdaptiveSpeedEnabled {
            menuController.setCPUStatus(
                "CPU: \(percentage)% · \(framesPerSecond) FPS"
            )
        } else {
            menuController.setCPUStatus(
                "CPU: \(percentage)% · Manual \(framesPerSecond) FPS"
            )
        }
    }

    private func loadImportedCharacter(
        kind: CharacterAssetKind,
        panelTitle: String
    ) {
        guard let url = choosePNG(title: panelTitle) else {
            return
        }

        do {
            let frames = try characterLibrary.frames(
                from: url,
                kind: kind
            )
            animationController.replaceFrames(frames)

            do {
                _ = try characterLibrary.persist(
                    sourceURL: url,
                    kind: kind
                )
                refreshRecentCharactersMenu()
            } catch {
                presentPersistenceWarning(error)
            }
        } catch {
            presentLoadError(error)
        }
    }

    private func loadRecentCharacter(id: UUID) {
        do {
            let asset = try characterLibrary.asset(id: id)
            let frames = try characterLibrary.frames(for: asset)
            animationController.replaceFrames(frames)
        } catch {
            presentLoadError(error)
            refreshRecentCharactersMenu()
        }
    }

    private func refreshRecentCharactersMenu() {
        do {
            let assets = try characterLibrary.recentAssets()
            menuController.setRecentCharacters(assets)
        } catch {
            menuController.setRecentCharactersUnavailable()
        }
    }

    private func choosePNG(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = "Load"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png]

        guard panel.runModal() == .OK else {
            return nil
        }

        return panel.url
    }

    private func toggleCPUAdaptiveSpeed() {
        isCPUAdaptiveSpeedEnabled.toggle()
        menuController.setAdaptiveSpeedEnabled(isCPUAdaptiveSpeedEnabled)

        if isCPUAdaptiveSpeedEnabled, let latestCPUUpdate {
            animationController.setFramesPerSecond(latestCPUUpdate.pace.framesPerSecond)
        }

        refreshCPUStatus()
    }

    private func changeAnimationSpeed(_ framesPerSecond: Double) {
        isCPUAdaptiveSpeedEnabled = false
        menuController.setAdaptiveSpeedEnabled(false)
        animationController.setFramesPerSecond(framesPerSecond)
        refreshCPUStatus()
    }

    private func presentLoadError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not load image"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func presentPersistenceWarning(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Character is running, but was not saved"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private static func menuBarImage(from source: NSImage) -> NSImage {
        let image = source.copy() as? NSImage ?? source
        let sourceWidth = max(source.size.width, 1)
        let sourceHeight = max(source.size.height, 1)
        let maximumWidth: CGFloat = 36
        let maximumHeight: CGFloat = 22
        let scale = min(
            maximumWidth / sourceWidth,
            maximumHeight / sourceHeight
        )

        image.size = NSSize(
            width: sourceWidth * scale,
            height: sourceHeight * scale
        )
        image.isTemplate = false
        return image
    }
}
