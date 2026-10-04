import IOKit.ps
import SchneeRunnerCore

@MainActor
final class SystemBatteryWarningMonitor {
    private var runLoopSource: CFRunLoopSource?
    private var currentLevel: BatteryWarningLevel?

    var onChange: ((BatteryWarningLevel) -> Void)?

    func start() {
        guard runLoopSource == nil else {
            return
        }

        refresh()

        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let source = IOPSNotificationCreateRunLoopSource(
            { context in
                guard let context else {
                    return
                }

                let monitor = Unmanaged<SystemBatteryWarningMonitor>
                    .fromOpaque(context)
                    .takeUnretainedValue()

                MainActor.assumeIsolated {
                    monitor.refresh()
                }
            },
            context
        )?.takeRetainedValue() else {
            return
        }

        CommonRunLoopSourceScheduler.add(source)
        runLoopSource = source
    }

    func stop() {
        guard let runLoopSource else {
            return
        }

        CommonRunLoopSourceScheduler.remove(runLoopSource)
        self.runLoopSource = nil
    }

    private func refresh() {
        let warning = IOPSGetBatteryWarningLevel()
        let level: BatteryWarningLevel = if warning == kIOPSLowBatteryWarningFinal {
            .final
        } else if warning == kIOPSLowBatteryWarningEarly {
            .early
        } else {
            .none
        }

        guard level != currentLevel else {
            return
        }

        currentLevel = level
        onChange?(level)
    }
}
