@testable import SchneeRunnerCore
import XCTest

final class LocalCharacterStateEventTests: XCTestCase {
    func testSetEventRoundTripsThroughJSON() throws {
        let event = try LocalCharacterStateEvent.set(
            state: .sprint,
            durationSeconds: 5,
            channel: "ci"
        )

        XCTAssertEqual(
            try LocalCharacterStateEvent.decodeJSON(
                event.encodedJSON()
            ),
            event
        )
    }

    func testPersistentSetEventUsesDefaultChannel() throws {
        let event = try LocalCharacterStateEvent.set(
            state: .idle
        )

        XCTAssertNil(event.durationSeconds)
        XCTAssertEqual(event.state, .idle)
        XCTAssertEqual(
            event.channel,
            LocalCharacterStateEvent.defaultChannel
        )
    }

    func testLegacyPayloadDefaultsToDefaultChannel() throws {
        let event = try LocalCharacterStateEvent.decodeJSON(
            """
            {
              "action": "set",
              "state": "run"
            }
            """
        )

        XCTAssertEqual(
            event.channel,
            LocalCharacterStateEvent.defaultChannel
        )
    }

    func testClearEventRoundTripsThroughJSON() throws {
        let event = LocalCharacterStateEvent.clear()

        XCTAssertEqual(
            try LocalCharacterStateEvent.decodeJSON(
                event.encodedJSON()
            ),
            event
        )
    }

    func testNamedClearEventRoundTripsThroughJSON() throws {
        let event = try LocalCharacterStateEvent.clear(
            channel: "tests.integration"
        )

        XCTAssertEqual(
            try LocalCharacterStateEvent.decodeJSON(
                event.encodedJSON()
            ),
            event
        )
    }

    func testRejectsDurationBelowMinimum() {
        XCTAssertThrowsError(
            try LocalCharacterStateEvent.set(
                state: .run,
                durationSeconds: 0.01
            )
        ) { error in
            XCTAssertEqual(
                error as? LocalCharacterStateEventError,
                .invalidDuration(0.01)
            )
        }
    }

    func testRejectsDurationAboveMaximum() {
        XCTAssertThrowsError(
            try LocalCharacterStateEvent.set(
                state: .run,
                durationSeconds: 3601
            )
        ) { error in
            XCTAssertEqual(
                error as? LocalCharacterStateEventError,
                .invalidDuration(3601)
            )
        }
    }

    func testRejectsInvalidChannel() {
        XCTAssertThrowsError(
            try LocalCharacterStateEvent.set(
                state: .run,
                channel: "ci/build"
            )
        ) { error in
            XCTAssertEqual(
                error as? LocalCharacterStateEventError,
                .invalidChannel("ci/build")
            )
        }
    }

    func testRejectsChannelAboveMaximumLength() {
        let channel = String(
            repeating: "a",
            count: LocalCharacterStateEvent.maximumChannelLength + 1
        )

        XCTAssertThrowsError(
            try LocalCharacterStateEvent.clear(
                channel: channel
            )
        ) { error in
            XCTAssertEqual(
                error as? LocalCharacterStateEventError,
                .invalidChannel(channel)
            )
        }
    }

    func testRejectsSetPayloadWithoutState() {
        let json = """
        {
          "action": "set",
          "durationSeconds": 5
        }
        """

        XCTAssertThrowsError(
            try LocalCharacterStateEvent.decodeJSON(json)
        ) { error in
            XCTAssertEqual(
                error as? LocalCharacterStateEventError,
                .stateRequired
            )
        }
    }

    func testRejectsClearPayloadWithState() {
        let json = """
        {
          "action": "clear",
          "state": "run"
        }
        """

        XCTAssertThrowsError(
            try LocalCharacterStateEvent.decodeJSON(json)
        ) { error in
            XCTAssertEqual(
                error as? LocalCharacterStateEventError,
                .clearPayloadMustBeEmpty
            )
        }
    }
}
