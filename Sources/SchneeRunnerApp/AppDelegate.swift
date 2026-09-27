import AppKit
import SchneeRunnerCore
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let animationController = AnimationController()
    private let cpuMonitor = CPUMonitor()

    private var statusItem: NSStatusItem?
    private var cpuUsageItem: NSMenuItem?
    private var adaptiveSpeedItem: NSMenuItem?
    private var latestCPUUpdate: CPUMonitor.Update?
    private var isCPUAdaptiveSpeedEnabled = true

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        configureStatusItem()
        configureAnimationCallback()
        configureCPUMonitor()
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
        item.menu = makeMenu()
        statusItem = item
    }

    private func configureAnimationCallback() {
        animationController.onFrame = { [weak self] image in
            self?.statusItem?.button?.image = Self.menuBarImage(from: image)
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
            self?.cpuUsageItem?.title = "CPU: unavailable"
        }
    }

    private func refreshCPUStatus() {
        guard let latestCPUUpdate else {
            return
        }

        let percentage = Int((latestCPUUpdate.utilization * 100).rounded())
        let framesPerSecond = Int(animationController.framesPerSecond.rounded())

        if isCPUAdaptiveSpeedEnabled {
            cpuUsageItem?.title = "CPU: \(percentage)% · \(framesPerSecond) FPS"
        } else {
            cpuUsageItem?.title = "CPU: \(percentage)% · Manual \(framesPerSecond) FPS"
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let loadItem = NSMenuItem(
            title: "Load 4x2 Sprite Sheet…",
            action: #selector(loadSpriteSheet),
            keyEquivalent: "o"
        )
        loadItem.target = self
        menu.addItem(loadItem)

        let cpuItem = NSMenuItem(title: "CPU: sampling…", action: nil, keyEquivalent: "")
        cpuItem.isEnabled = false
        menu.addItem(cpuItem)
        cpuUsageItem = cpuItem

        let adaptiveItem = NSMenuItem(
            title: "CPU Adaptive Speed",
            action: #selector(toggleCPUAdaptiveSpeed),
            keyEquivalent: ""
        )
        adaptiveItem.target = self
        adaptiveItem.state = .on
        menu.addItem(adaptiveItem)
        adaptiveSpeedItem = adaptiveItem

        let speedMenu = NSMenu(title: "Animation Speed")
        for framesPerSecond in [6, 8, 12, 18, 24] {
            let speedItem = NSMenuItem(
                title: "\(framesPerSecond) FPS",
                action: #selector(changeAnimationSpeed(_:)),
                keyEquivalent: ""
            )
            speedItem.target = self
            speedItem.tag = framesPerSecond
            speedMenu.addItem(speedItem)
        }

        let speedRootItem = NSMenuItem(title: "Manual Speed", action: nil, keyEquivalent: "")
        speedRootItem.submenu = speedMenu
        menu.addItem(speedRootItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit SchneeRunner",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func loadSpriteSheet() {
        let panel = NSOpenPanel()
        panel.title = "Choose a 4x2 Sprite Sheet"
        panel.prompt = "Load"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.png]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let grid = try SpriteSheetGrid(columns: 4, rows: 2)
            let frames = try SpriteSheetLoader(grid: grid).loadFrames(from: url)
            animationController.replaceFrames(frames)
        } catch {
            presentLoadError(error)
        }
    }

    @objc
    private func toggleCPUAdaptiveSpeed() {
        isCPUAdaptiveSpeedEnabled.toggle()
        adaptiveSpeedItem?.state = isCPUAdaptiveSpeedEnabled ? .on : .off

        if isCPUAdaptiveSpeedEnabled, let latestCPUUpdate {
            animationController.setFramesPerSecond(latestCPUUpdate.pace.framesPerSecond)
        }

        refreshCPUStatus()
    }

    @objc
    private func changeAnimationSpeed(_ sender: NSMenuItem) {
        isCPUAdaptiveSpeedEnabled = false
        adaptiveSpeedItem?.state = .off
        animationController.setFramesPerSecond(Double(sender.tag))
        refreshCPUStatus()
    }

    @objc
    private func quitApplication() {
        NSApplication.shared.terminate(nil)
    }

    private func presentLoadError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not load sprite sheet"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private static func menuBarImage(from source: NSImage) -> NSImage {
        let image = source.copy() as? NSImage ?? source
        let sourceHeight = max(source.size.height, 1)
        let displayHeight: CGFloat = 22
        let aspectRatio = source.size.width / sourceHeight
        let displayWidth = min(displayHeight * aspectRatio, 36)

        image.size = NSSize(width: displayWidth, height: displayHeight)
        image.isTemplate = false
        return image
    }
}
