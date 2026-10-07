import AppKit
import SchneeRunnerCore

@MainActor
final class StatusMenuController: NSObject {
    let menu = NSMenu()

    var onLoadSingleImage: (() -> Void)?
    var onLoadSpriteSheet: (() -> Void)?
    var onLoadPNGSequence: (() -> Void)?
    var onLoadGIF: (() -> Void)?
    var onLoadAPNG: (() -> Void)?
    var onLoadWebP: (() -> Void)?
    var onLoadCharacterPack: (() -> Void)?
    var onBuildCharacterPack: (() -> Void)?
    var onExportCharacterPack: (() -> Void)?
    var onLoadRecentCharacter: ((UUID) -> Void)?
    var onRefreshRecentCharacters: (() -> Void)?
    var onStartTimerPreset: ((TimeInterval) -> Void)?
    var onStartCustomTimer: (() -> Void)?
    var onManageTimers: (() -> Void)?
    var onPauseTimer: ((UUID) -> Void)?
    var onResumeTimer: ((UUID) -> Void)?
    var onCancelTimer: ((UUID) -> Void)?
    var onStartPomodoro: ((PomodoroConfiguration) -> Void)?
    var onPausePomodoro: (() -> Void)?
    var onResumePomodoro: (() -> Void)?
    var onStartPomodoroPhase: (() -> Void)?
    var onStopPomodoro: (() -> Void)?
    var onPomodoroSettings: (() -> Void)?
    var onNewReminder: (() -> Void)?
    var onManageReminders: (() -> Void)?
    var onToggleProductivityCharacterReactions: (() -> Void)?
    var onToggleCPUAdaptiveSpeed: (() -> Void)?
    var onCharacterStateOverride: ((CharacterState?) -> Void)?
    var onManualSpeed: ((Double) -> Void)?
    var onDesktopCharacterConfigurationChanged: ((DesktopCharacterMenuConfiguration) -> Void)?
    var onResetDesktopCharacterPlacement: (() -> Void)?
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
    private let productivityNotificationStatusItem = NSMenuItem(
        title: "Productivity Notifications: Disabled",
        action: nil,
        keyEquivalent: ""
    )
    private let productivityCharacterReactionsItem = NSMenuItem(
        title: "Productivity Character Reactions",
        action: nil,
        keyEquivalent: ""
    )
    private let recentCharactersMenu = NSMenu(title: "Recent Characters")
    private let timerMenuController = TimerMenuController()
    private let pomodoroMenuController = PomodoroMenuController()
    private let reminderMenuController = ReminderMenuController()
    private let stateMenuController = CharacterStateMenuController()
    private let desktopCharacterMenuController = DesktopCharacterMenuController()
    private let launchAtLoginMenuController = LaunchAtLoginMenuController()
    private let exportCharacterPackItem = NSMenuItem(
        title: "Export Current Character Pack…",
        action: nil,
        keyEquivalent: ""
    )

    override init() {
        super.init()
        configureTimerCallbacks()
        configurePomodoroCallbacks()
        configureReminderCallbacks()
        stateMenuController.onSelection = { [weak self] state in
            self?.onCharacterStateOverride?(state)
        }
        desktopCharacterMenuController.onConfigurationChanged = { [weak self] configuration in
            self?.onDesktopCharacterConfigurationChanged?(configuration)
        }
        desktopCharacterMenuController.onResetPlacement = { [weak self] in
            self?.onResetDesktopCharacterPlacement?()
        }
        menu.delegate = self
        buildMenu()
    }

    var desktopCharacterConfiguration: DesktopCharacterMenuConfiguration {
        desktopCharacterMenuController.configuration
    }

    func setCPUStatus(_ title: String) {
        cpuUsageItem.title = title
    }

    func setAdaptiveSpeedEnabled(_ isEnabled: Bool) {
        adaptiveSpeedItem.state = isEnabled ? .on : .off
    }

    func setProductivityNotificationStatus(
        _ status: ProductivityNotificationDeliveryStatus
    ) {
        productivityNotificationStatusItem.isHidden = status != .disabled
    }

    func setProductivityCharacterReactionsEnabled(_ isEnabled: Bool) {
        productivityCharacterReactionsItem.state = isEnabled ? .on : .off
    }

    func setCharacterStateOverride(_ state: CharacterState?) {
        stateMenuController.setSelection(state)
    }

    func setTimers(
        _ timers: [ProductivityCountdownTimer],
        now: Date
    ) {
        timerMenuController.setTimers(timers, now: now)
    }

    func setPomodoroConfiguration(_ configuration: PomodoroConfiguration) {
        pomodoroMenuController.setConfiguration(configuration)
    }

    func setPomodoroSession(
        _ session: PomodoroSession?,
        now: Date
    ) {
        pomodoroMenuController.setSession(session, now: now)
    }

    func setReminders(
        _ reminders: [ProductivityReminder],
        now: Date,
        calendar: Calendar = .current
    ) {
        reminderMenuController.setReminders(
            reminders,
            now: now,
            calendar: calendar
        )
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

    func setCharacterPackExportEnabled(_ isEnabled: Bool) {
        exportCharacterPackItem.isEnabled = isEnabled
    }
}

private extension StatusMenuController {
    func configureTimerCallbacks() {
        timerMenuController.onStartPreset = { [weak self] duration in
            self?.onStartTimerPreset?(duration)
        }
        timerMenuController.onStartCustomTimer = { [weak self] in
            self?.onStartCustomTimer?()
        }
        timerMenuController.onManageTimers = { [weak self] in
            self?.onManageTimers?()
        }
        timerMenuController.onPauseTimer = { [weak self] id in
            self?.onPauseTimer?(id)
        }
        timerMenuController.onResumeTimer = { [weak self] id in
            self?.onResumeTimer?(id)
        }
        timerMenuController.onCancelTimer = { [weak self] id in
            self?.onCancelTimer?(id)
        }
    }

    func configurePomodoroCallbacks() {
        pomodoroMenuController.onStart = { [weak self] configuration in
            self?.onStartPomodoro?(configuration)
        }
        pomodoroMenuController.onPause = { [weak self] in
            self?.onPausePomodoro?()
        }
        pomodoroMenuController.onResume = { [weak self] in
            self?.onResumePomodoro?()
        }
        pomodoroMenuController.onStartCurrentPhase = { [weak self] in
            self?.onStartPomodoroPhase?()
        }
        pomodoroMenuController.onStop = { [weak self] in
            self?.onStopPomodoro?()
        }
        pomodoroMenuController.onSettings = { [weak self] in
            self?.onPomodoroSettings?()
        }
    }

    func configureReminderCallbacks() {
        reminderMenuController.onNewReminder = { [weak self] in
            self?.onNewReminder?()
        }
        reminderMenuController.onManageReminders = { [weak self] in
            self?.onManageReminders?()
        }
    }

    func buildMenu() {
        addImportItems()
        addRecentCharactersItem()
        addExportItem()
        menu.addItem(.separator())
        menu.addItem(timerMenuController.rootItem)
        menu.addItem(pomodoroMenuController.rootItem)
        menu.addItem(reminderMenuController.rootItem)
        addProductivityNotificationStatusItem()
        addProductivityReactionItem()
        menu.addItem(.separator())
        addCPUItems()
        menu.addItem(stateMenuController.rootItem)
        addManualSpeedItem()
        menu.addItem(.separator())
        menu.addItem(desktopCharacterMenuController.item)
        menu.addItem(launchAtLoginMenuController.item)
        addQuitItem()
    }

    func addImportItems() {
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

        let apngItem = NSMenuItem(
            title: "Load APNG…",
            action: #selector(loadAPNG),
            keyEquivalent: ""
        )
        apngItem.target = self
        menu.addItem(apngItem)

        let webPItem = NSMenuItem(
            title: "Load WebP…",
            action: #selector(loadWebP),
            keyEquivalent: ""
        )
        webPItem.target = self
        menu.addItem(webPItem)

        let packItem = NSMenuItem(
            title: "Load Character Pack…",
            action: #selector(loadCharacterPack),
            keyEquivalent: ""
        )
        packItem.target = self
        menu.addItem(packItem)

        let buildPackItem = NSMenuItem(
            title: "Build Character Pack…",
            action: #selector(buildCharacterPack),
            keyEquivalent: ""
        )
        buildPackItem.target = self
        menu.addItem(buildPackItem)
    }

    func addExportItem() {
        exportCharacterPackItem.target = self
        exportCharacterPackItem.action = #selector(exportCharacterPack)
        exportCharacterPackItem.isEnabled = false
        menu.addItem(exportCharacterPackItem)
    }

    func addRecentCharactersItem() {
        let item = NSMenuItem(
            title: "Recent Characters",
            action: nil,
            keyEquivalent: ""
        )
        item.submenu = recentCharactersMenu
        menu.addItem(item)
    }

    func addProductivityNotificationStatusItem() {
        productivityNotificationStatusItem.isEnabled = false
        productivityNotificationStatusItem.isHidden = true
        menu.addItem(productivityNotificationStatusItem)
    }

    func addProductivityReactionItem() {
        productivityCharacterReactionsItem.target = self
        productivityCharacterReactionsItem.action = #selector(toggleProductivityCharacterReactions)
        productivityCharacterReactionsItem.state = .on
        menu.addItem(productivityCharacterReactionsItem)
    }

    func addCPUItems() {
        cpuUsageItem.isEnabled = false
        menu.addItem(cpuUsageItem)

        adaptiveSpeedItem.target = self
        adaptiveSpeedItem.action = #selector(toggleCPUAdaptiveSpeed)
        adaptiveSpeedItem.state = .on
        menu.addItem(adaptiveSpeedItem)
    }

    func addManualSpeedItem() {
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

    func addQuitItem() {
        let item = NSMenuItem(
            title: "Quit SchneeRunner",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        item.target = self
        menu.addItem(item)
    }

    func recentCharacterTitle(
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
        case .apng:
            "APNG"
        case .webP:
            "WebP"
        case .characterPack:
            "Character Pack"
        }

        return "\(asset.displayName) · \(mode)"
    }

    func addDisabledRecentItem(title: String) {
        let item = NSMenuItem(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        recentCharactersMenu.addItem(item)
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuWillOpen(_: NSMenu) {
        onRefreshRecentCharacters?()
        pomodoroMenuController.refresh(now: Date())
        launchAtLoginMenuController.refresh()
    }
}
