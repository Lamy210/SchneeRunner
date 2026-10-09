@MainActor
final class ProductivityFallbackRouter {
    private let presenter: any ProductivityFallbackPresenting
    private var notificationStatus: ProductivityNotificationDeliveryStatus?
    private var pendingEvents: [ProductivityFallbackEvent] = []

    init(
        presenter: any ProductivityFallbackPresenting,
        initialNotificationStatus: ProductivityNotificationDeliveryStatus? = nil
    ) {
        self.presenter = presenter
        notificationStatus = initialNotificationStatus
    }

    func enqueue(_ event: ProductivityFallbackEvent) {
        switch notificationStatus {
        case .disabled?:
            presenter.present(event)
        case .scheduled?:
            break
        case nil:
            pendingEvents.append(event)
        }
    }

    func updateNotificationStatus(_ status: ProductivityNotificationDeliveryStatus) {
        notificationStatus = status

        switch status {
        case .scheduled:
            pendingEvents.removeAll()
        case .disabled:
            let events = pendingEvents
            pendingEvents.removeAll()
            for event in events {
                presenter.present(event)
            }
        }
    }
}
