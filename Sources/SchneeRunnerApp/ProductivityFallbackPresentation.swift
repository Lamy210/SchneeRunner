import SchneeRunnerCore

@MainActor
enum ProductivityFallbackEvent: Equatable, Sendable {
    case timerCompleted(title: String)
    case pomodoroPhaseCompleted(phase: PomodoroPhase)
    case reminderDue(title: String, body: String?)
}

@MainActor
protocol ProductivityFallbackPresenting: AnyObject {
    func present(_ event: ProductivityFallbackEvent)
}
