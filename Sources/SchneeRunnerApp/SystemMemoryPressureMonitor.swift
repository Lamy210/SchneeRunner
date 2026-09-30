import Dispatch
import SchneeRunnerCore

@MainActor
final class SystemMemoryPressureMonitor {
    private var source: (any DispatchSourceMemoryPressure)?

    var onChange: ((MemoryPressureLevel) -> Void)?

    func start() {
        guard source == nil else {
            return
        }

        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: .all,
            queue: .main
        )
        source.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleMemoryPressureEvent()
            }
        }

        self.source = source
        source.activate()
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    private func handleMemoryPressureEvent() {
        guard
            let source,
            let level = Self.level(for: source.data)
        else {
            return
        }

        onChange?(level)
    }

    private static func level(
        for event: DispatchSource.MemoryPressureEvent
    ) -> MemoryPressureLevel? {
        if event.contains(.critical) {
            return .critical
        }
        if event.contains(.warning) {
            return .warning
        }
        if event.contains(.normal) {
            return .normal
        }

        return nil
    }
}
