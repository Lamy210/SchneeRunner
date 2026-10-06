import Foundation
@testable import SchneeRunnerCore
import XCTest

final class ProductivityHistoryTests: XCTestCase {
    func testAppendingKeepsNewestFiveHundredEntries() throws {
        let base = Date(timeIntervalSince1970: 1_791_331_200)
        var history = ProductivityHistory()

        for index in 0 ... 500 {
            history = history.appending(
                ProductivityHistoryEntry(
                    id: UUID(),
                    kind: .countdownCompleted,
                    sourceID: UUID(),
                    title: "Timer \(index)",
                    occurredAt: base.addingTimeInterval(TimeInterval(index))
                )
            )
        }

        XCTAssertEqual(history.entries.count, 500)
        XCTAssertEqual(history.entries.first?.title, "Timer 1")
        XCTAssertEqual(history.entries.last?.title, "Timer 500")
    }

    func testDecodeRejectsUnsupportedSchemaVersion() throws {
        let data = Data("{\"schemaVersion\":999,\"entries\":[]}".utf8)

        XCTAssertThrowsError(
            try JSONDecoder().decode(ProductivityHistory.self, from: data)
        ) { error in
            XCTAssertEqual(
                error as? ProductivityHistoryError,
                .unsupportedSchemaVersion(999)
            )
        }
    }

    func testAppendingPreservesInsertionOrderWithoutResortingByTimestamp() {
        let later = Date(timeIntervalSince1970: 200)
        let earlier = Date(timeIntervalSince1970: 100)
        let first = ProductivityHistoryEntry(
            id: UUID(),
            kind: .reminderDelivered,
            sourceID: UUID(),
            title: "First",
            occurredAt: later
        )
        let second = ProductivityHistoryEntry(
            id: UUID(),
            kind: .pomodoroBreakCompleted,
            sourceID: UUID(),
            title: "Second",
            occurredAt: earlier
        )

        let history = ProductivityHistory().appending(first).appending(second)

        XCTAssertEqual(history.entries, [first, second])
    }
}
