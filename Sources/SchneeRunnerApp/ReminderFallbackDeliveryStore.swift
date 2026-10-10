import Foundation

@MainActor
final class ReminderFallbackDeliveryStore {
    static let defaultKey = "SchneeRunner.reminderFallbackDeliveredOccurrences"
    static let defaultMaximumEntries = 256

    private let defaults: UserDefaults
    private let key: String
    private let maximumEntries: Int

    init(
        defaults: UserDefaults = .standard,
        key: String = defaultKey,
        maximumEntries: Int = defaultMaximumEntries
    ) {
        self.defaults = defaults
        self.key = key
        self.maximumEntries = max(1, maximumEntries)
    }

    func contains(_ occurrenceID: String) -> Bool {
        deliveredOccurrenceIDs.contains(occurrenceID)
    }

    func record(_ occurrenceID: String) {
        var ids = deliveredOccurrenceIDs.filter { $0 != occurrenceID }
        ids.append(occurrenceID)
        if ids.count > maximumEntries {
            ids.removeFirst(ids.count - maximumEntries)
        }
        defaults.set(ids, forKey: key)
    }

    private var deliveredOccurrenceIDs: [String] {
        defaults.stringArray(forKey: key) ?? []
    }
}
