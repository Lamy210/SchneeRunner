import AppKit
import ServiceManagement

enum LaunchAtLoginServiceStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

@MainActor
protocol LaunchAtLoginServicing: AnyObject {
    var status: LaunchAtLoginServiceStatus { get }
    func register() throws
    func unregister() throws
    func openSystemSettingsLoginItems()
}

@MainActor
final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LaunchAtLoginServiceStatus {
        switch service.status {
        case .enabled:
            .enabled
        case .notRegistered:
            .notRegistered
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .notFound
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openSystemSettingsLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

@MainActor
final class LaunchAtLoginMenuController: NSObject {
    let item: NSMenuItem

    private let service: any LaunchAtLoginServicing
    private let isAvailable: Bool
    private let localization: AppLocalization

    init(
        service: any LaunchAtLoginServicing = SystemLaunchAtLoginService(),
        isAvailable: Bool = RuntimeCapabilities.current.launchAtLoginAvailable,
        localization: AppLocalization = .current
    ) {
        self.service = service
        self.isAvailable = isAvailable
        self.localization = localization
        item = NSMenuItem(
            title: localization.string("launchAtLogin.title"),
            action: nil,
            keyEquivalent: ""
        )
        super.init()

        item.target = self
        item.action = #selector(toggleLaunchAtLogin)
        refresh()
    }

    func refresh() {
        guard isAvailable else {
            setUnavailable()
            return
        }

        switch service.status {
        case .enabled:
            item.title = localization.string("launchAtLogin.title")
            item.state = .on
            item.isEnabled = true

        case .notRegistered:
            item.title = localization.string("launchAtLogin.title")
            item.state = .off
            item.isEnabled = true

        case .requiresApproval:
            item.title = "\(localization.string("launchAtLogin.title")) (Approval Required)"
            item.state = .off
            item.isEnabled = true

        case .notFound:
            setUnavailable()
        }
    }

    @objc
    func toggleLaunchAtLogin() {
        guard isAvailable else {
            return
        }

        do {
            switch service.status {
            case .enabled:
                try service.unregister()

            case .notRegistered:
                try service.register()

            case .requiresApproval:
                service.openSystemSettingsLoginItems()

            case .notFound:
                return
            }

            refresh()
        } catch {
            presentError(error)
            refresh()
        }
    }

    private func setUnavailable() {
        item.title = localization.string("launchAtLogin.unavailable")
        item.state = .off
        item.isEnabled = false
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not update Launch at Login"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
