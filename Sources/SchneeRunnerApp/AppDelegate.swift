import AppKit
import SchneeRunnerCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let animationController = AnimationController()
    private let cpuMonitor = CPUMonitor()
    private let characterLibrary = CharacterLibraryController()
    private let frameRendererCoordinator = CharacterFrameRendererCoordinator()
    private let importPresenter = CharacterImportPresenter()
    private let packBuilderPresenter = CharacterPackBuilderPresenter()
    private let menuController = StatusMenuController()

    private lazy var characterPlaybackController = CharacterPlaybackController(
        animationController: animationController
    )
    private lazy var characterStateCoordinator = CharacterStateCoordinator(
        playbackController: characterPlaybackController
    )

    private var statusItem: NSStatusItem?
    private var currentAsset: StoredCharacterAsset?
    private var latestCPUUpdate: CPUMonitor.Update?
    private var cpuStatus: CPUStatusValue = .sampling
    private var isCPUAdaptiveSpeedEnabled = true
    private var unavailableRecentCharacterIDs: Set<UUID> = []

    func applicationDidFinishLaunching(_: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        configureStatusItem()
        configureAnimationCallback()
        configurePlaybackCallback()
        configureMenuCallbacks()
        configureCPUMonitor()
        restoreLastCharacter()
        refreshRecentCharactersMenu()
        characterStateCoordinator.start()
        cpuMonitor.start()
    }

    func applicationWillTerminate(_: Notification) {
        characterStateCoordinator.stop()
        cpuMonitor.stop()
        animationController.stop()
        frameRendererCoordinator.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "figure.run",
            accessibilityDescription: "SchneeRunner"
        )
        item.menu = menuController.menu
        statusItem = item
        frameRendererCoordinator.bind(statusItem: item)
    }

    private func configureAnimationCallback() {
        animationController.onFrame = { [weak self] image in
            self?.frameRendererCoordinator.render(image)
        }
    }

    private func configurePlaybackCallback() {
        characterPlaybackController.onStateChange = { [weak self] in
            self?.refreshCPUStatus()
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
        menuController.onLoadPNGSequence = { [weak self] in
            self?.loadPNGSequence()
        }
        menuController.onLoadGIF = { [weak self] in
            self?.loadGIF()
        }
        menuController.onLoadAPNG = { [weak self] in
            self?.loadAnimatedImage(format: .apng)
        }
        menuController.onLoadWebP = { [weak self] in
            self?.loadAnimatedImage(format: .webP)
        }
        menuController.onLoadCharacterPack = { [weak self] in
            self?.loadCharacterPack()
        }
        menuController.onBuildCharacterPack = { [weak self] in
            self?.buildCharacterPack()
        }
        menuController.onExportCharacterPack = { [weak self] in
            self?.exportCurrentCharacterPack()
        }
        menuController.onLoadRecentCharacter = { [weak self] id in
            self?.loadRecentCharacter(id: id)
        }
        menuController.onToggleCPUAdaptiveSpeed = { [weak self] in
            self?.toggleCPUAdaptiveSpeed()
        }
        menuController.onCharacterStateOverride = { [weak self] state in
            self?.setCharacterStateOverride(state)
        }
        menuController.onManualSpeed = { [weak self] framesPerSecond in
            self?.changeAnimationSpeed(framesPerSecond)
        }
        menuController.onDesktopCharacterConfigurationChanged = { [weak self] configuration in
            self?.frameRendererCoordinator.setDesktopConfiguration(
                configuration
            )
        }
        menuController.onResetDesktopCharacterPlacement = { [weak self] in
            self?.frameRendererCoordinator.resetDesktopPlacement()
        }
        frameRendererCoordinator.setDesktopConfiguration(
            menuController.desktopCharacterConfiguration
        )
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
            cpuStatus = .utilization(update.utilization)

            if isCPUAdaptiveSpeedEnabled {
                characterStateCoordinator.updateCPUState(
                    for: update.pace
                )
                animationController.setFramesPerSecond(
                    update.pace.framesPerSecond
                )
            }

            refreshCPUStatus()
        }

        cpuMonitor.onError = { [weak self] _ in
            guard let self else {
                return
            }

            latestCPUUpdate = nil
            cpuStatus = .unavailable
            characterStateCoordinator.clearCPUState()
            refreshCPUStatus()
        }
    }

    private func refreshCPUStatus() {
        menuController.setCPUStatus(
            CPUStatusFormatter.title(
                status: cpuStatus,
                requestedState: characterPlaybackController.requestedState,
                resolvedState: characterPlaybackController.resolvedState,
                playbackRate: animationController.playbackRate,
                isAdaptiveSpeedEnabled: isCPUAdaptiveSpeedEnabled
            )
        )
    }
}

private extension AppDelegate {
    func loadImportedCharacter(
        kind: CharacterAssetKind,
        panelTitle: String
    ) {
        guard let url = importPresenter.choosePNG(title: panelTitle) else {
            return
        }

        do {
            let frames = try characterLibrary.frames(
                from: url,
                kind: kind
            )
            try play(frames: frames)

            do {
                let asset = try characterLibrary.persist(
                    sourceURL: url,
                    kind: kind
                )
                setCurrentAsset(asset)
                characterLibrary.rememberSelection(asset)
                refreshRecentCharactersMenu()
            } catch {
                importPresenter.presentPersistenceWarning(error)
            }
        } catch {
            importPresenter.presentLoadError(error)
        }
    }

    func loadPNGSequence() {
        guard let urls = importPresenter.choosePNGs(
            title: "Choose PNG Sequence Frames"
        ) else {
            return
        }

        do {
            let frames = try characterLibrary.frames(
                fromPNGSequence: urls
            )
            try play(frames: frames)

            do {
                let asset = try characterLibrary.persistPNGSequence(
                    sourceURLs: urls
                )
                setCurrentAsset(asset)
                characterLibrary.rememberSelection(asset)
                refreshRecentCharactersMenu()
            } catch {
                importPresenter.presentPersistenceWarning(error)
            }
        } catch {
            importPresenter.presentLoadError(error)
        }
    }

    func loadGIF() {
        guard let url = importPresenter.chooseGIF(
            title: "Choose an Animated GIF"
        ) else {
            return
        }

        do {
            let animation = try characterLibrary.animation(
                fromGIF: url
            )
            play(animation)

            do {
                let asset = try characterLibrary.persistGIF(
                    sourceURL: url
                )
                setCurrentAsset(asset)
                characterLibrary.rememberSelection(asset)
                refreshRecentCharactersMenu()
            } catch {
                importPresenter.presentPersistenceWarning(error)
            }
        } catch {
            importPresenter.presentLoadError(error)
        }
    }

    func loadAnimatedImage(
        format: AnimatedImageFormat
    ) {
        let url = switch format {
        case .apng:
            importPresenter.chooseAPNG(
                title: "Choose an Animated PNG"
            )
        case .webP:
            importPresenter.chooseWebP(
                title: "Choose an Animated WebP"
            )
        }

        guard let url else {
            return
        }

        do {
            let animation = try characterLibrary.animation(
                fromAnimatedImage: url,
                format: format
            )
            play(animation)

            do {
                let asset = try characterLibrary.persistAnimatedImage(
                    sourceURL: url,
                    format: format
                )
                setCurrentAsset(asset)
                characterLibrary.rememberSelection(asset)
                refreshRecentCharactersMenu()
            } catch {
                importPresenter.presentPersistenceWarning(error)
            }
        } catch {
            importPresenter.presentLoadError(error)
        }
    }

    func loadCharacterPack() {
        guard let url = importPresenter.chooseCharacterPack(
            title: "Choose a .schneerunner Character Pack"
        ) else {
            return
        }

        do {
            let library = try characterLibrary.library(
                fromCharacterPack: url
            )
            play(library)

            do {
                let asset = try characterLibrary.persistCharacterPack(
                    sourceURL: url
                )
                setCurrentAsset(asset)
                characterLibrary.rememberSelection(asset)
                refreshRecentCharactersMenu()
            } catch {
                importPresenter.presentPersistenceWarning(error)
            }
        } catch {
            importPresenter.presentLoadError(error)
        }
    }

    func buildCharacterPack() {
        guard let request = packBuilderPresenter
            .chooseBuildRequest()
        else {
            return
        }

        guard let destinationURL = importPresenter
            .chooseCharacterPackBuildDestination(
                suggestedName: request.name
            )
        else {
            return
        }

        do {
            try characterLibrary.buildCharacterPack(
                request,
                at: destinationURL
            )
            importPresenter.presentBuildSuccess(
                destinationURL
            )
        } catch {
            importPresenter.presentBuildError(error)
        }
    }

    func exportCurrentCharacterPack() {
        guard
            let asset = currentAsset,
            asset.kind == .characterPack
        else {
            return
        }

        guard let destinationURL = importPresenter
            .chooseCharacterPackExportDestination(
                suggestedName: asset.displayName
            )
        else {
            return
        }

        do {
            try characterLibrary.exportCharacterPack(
                asset,
                to: destinationURL
            )
        } catch {
            importPresenter.presentExportError(error)
        }
    }

    func loadRecentCharacter(id: UUID) {
        do {
            let asset = try characterLibrary.asset(id: id)
            let library = try characterLibrary.library(for: asset)
            play(library)
            setCurrentAsset(asset)
            characterLibrary.rememberSelection(asset)
        } catch {
            unavailableRecentCharacterIDs.insert(id)
            importPresenter.presentLoadError(error)
            refreshRecentCharactersMenu()
        }
    }

    func refreshRecentCharactersMenu() {
        do {
            let assets = try characterLibrary.recentAssets(
                excluding: unavailableRecentCharacterIDs
            )
            menuController.setRecentCharacters(assets)
        } catch {
            menuController.setRecentCharactersUnavailable()
        }
    }

    func restoreLastCharacter() {
        do {
            guard let asset = try characterLibrary.lastSelectedAsset() else {
                return
            }

            let library = try characterLibrary.library(for: asset)
            play(library)
            setCurrentAsset(asset)
        } catch {
            if let asset = try? characterLibrary.lastSelectedAsset() {
                unavailableRecentCharacterIDs.insert(asset.id)
            }
            characterLibrary.clearLastSelection()
        }
    }
}

private extension AppDelegate {
    func play(frames: [NSImage]) throws {
        let animation = try LoadedAnimation.uniform(
            frames: frames
        )
        play(animation)
    }

    func play(_ animation: LoadedAnimation) {
        play(
            CharacterAnimationLibrary.single(
                animation: animation
            )
        )
    }

    func play(_ library: CharacterAnimationLibrary) {
        setCurrentAsset(nil)
        characterPlaybackController.install(library)
    }

    func setCurrentAsset(_ asset: StoredCharacterAsset?) {
        currentAsset = asset
        menuController.setCharacterPackExportEnabled(
            asset?.kind == .characterPack
        )
    }

    func toggleCPUAdaptiveSpeed() {
        isCPUAdaptiveSpeedEnabled.toggle()
        menuController.setAdaptiveSpeedEnabled(isCPUAdaptiveSpeedEnabled)

        if isCPUAdaptiveSpeedEnabled {
            if let latestCPUUpdate {
                characterStateCoordinator.updateCPUState(
                    for: latestCPUUpdate.pace
                )
                animationController.setFramesPerSecond(
                    latestCPUUpdate.pace.framesPerSecond
                )
            }
        } else {
            characterStateCoordinator.clearCPUState()
        }

        refreshCPUStatus()
    }

    func setCharacterStateOverride(_ state: CharacterState?) {
        characterStateCoordinator.setManualOverride(state)
        menuController.setCharacterStateOverride(state)
        refreshCPUStatus()
    }

    func changeAnimationSpeed(_ framesPerSecond: Double) {
        isCPUAdaptiveSpeedEnabled = false
        menuController.setAdaptiveSpeedEnabled(false)
        characterStateCoordinator.clearCPUState()
        animationController.setFramesPerSecond(framesPerSecond)
        refreshCPUStatus()
    }
}
