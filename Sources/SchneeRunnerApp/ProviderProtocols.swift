@MainActor
protocol MetricProvider<Metric>: AnyObject {
    associatedtype Metric

    var onUpdate: ((Metric) -> Void)? { get set }

    func start()
    func stop()
}

@MainActor
protocol EventProvider<Event>: AnyObject {
    associatedtype Event

    var onEvent: ((Event) -> Void)? { get set }

    func start()
    func stop()
}
