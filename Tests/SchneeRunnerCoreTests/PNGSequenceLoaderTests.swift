@testable import SchneeRunnerCore
import XCTest

final class PNGSequenceLoaderTests: XCTestCase {
    func testOrdersFrameNamesNumerically() {
        let loader = PNGSequenceLoader()
        let urls = [
            URL(fileURLWithPath: "/tmp/frame10.png"),
            URL(fileURLWithPath: "/tmp/frame2.png"),
            URL(fileURLWithPath: "/tmp/frame1.png")
        ]

        XCTAssertEqual(
            loader.orderedSourceURLs(urls).map(\.lastPathComponent),
            ["frame1.png", "frame2.png", "frame10.png"]
        )
    }

    func testRejectsSingleFrameSequence() {
        let loader = PNGSequenceLoader()

        XCTAssertThrowsError(
            try loader.validatedOrderedURLs([
                URL(fileURLWithPath: "/tmp/frame1.png")
            ])
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceLoaderError,
                .insufficientFrames(actual: 1)
            )
        }
    }

    func testRejectsSequenceOverConfiguredLimit() {
        let loader = PNGSequenceLoader(maximumFrameCount: 2)

        XCTAssertThrowsError(
            try loader.validatedOrderedURLs([
                URL(fileURLWithPath: "/tmp/frame1.png"),
                URL(fileURLWithPath: "/tmp/frame2.png"),
                URL(fileURLWithPath: "/tmp/frame3.png")
            ])
        ) { error in
            XCTAssertEqual(
                error as? PNGSequenceLoaderError,
                .tooManyFrames(actual: 3, maximum: 2)
            )
        }
    }
}
