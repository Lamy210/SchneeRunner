import AppKit
import ServiceManagement

@MainActor
final class LaunchAtLoginMenuController: NSObject {
    let item = NSMenuItem(
        title: "Launch at Login",
        action: nil,
        keyEquivalent: ""
    )

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
        super.init()

        item.target = self
        item.action = #selector(toggleLaunchAtLogin)
        refresh()
    }

    func refresh() {
        switch service.status {
        case .enabled:
            item.title = "Launch at Login"
            item.state = .on
            item.isEnabled = true

        case .notRegistered:
            item.title = "Launch at Login"
            item.state = .off
            item.isEnabled = true

        case .requiresApproval:
            item.title = "Launch at Login (Approval Required)"
            item.state = .off
            item.isEnabled = true

        case .notFound:
            setUnavailable()

        @unknown default:
            setUnavailable()
        }
    }

    @objc
    private func toggleLaunchAtLogin() {
        do {
            switch service.status {
            case .enabled:
                try service.unregister()

            case .notRegistered:
                try service.register()

            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()

            case .notFound:
                return

            @unknown default:
                return
            }

            refresh()
        } catch {
            presentError(error)
            refresh()
        }
    }

    private func setUnavailable() {
        item.title = "Launch at Login (Unavailable)"
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
