@testable import SchneeRunnerCore
import XCTest

final class SpriteSheetGridTests: XCTestCase {
    func testFourByTwoGridProducesEightFramesInDisplayOrder() throws {
        let grid = try SpriteSheetGrid(columns: 4, rows: 2)

        let frames = try grid.frames(imageWidth: 1600, imageHeight: 800)

        XCTAssertEqual(frames.count, 8)
        XCTAssertEqual(frames[0], SpriteSheetFrame(x: 0, y: 0, width: 400, height: 400))
        XCTAssertEqual(frames[3], SpriteSheetFrame(x: 1200, y: 0, width: 400, height: 400))
        XCTAssertEqual(frames[4], SpriteSheetFrame(x: 0, y: 400, width: 400, height: 400))
        XCTAssertEqual(frames[7], SpriteSheetFrame(x: 1200, y: 400, width: 400, height: 400))
    }

    func testFourByTwoGridPartitionsOddImageDimensionsWithoutDroppingPixels() throws {
        let grid = try SpriteSheetGrid(columns: 4, rows: 2)

        let frames = try grid.frames(imageWidth: 1774, imageHeight: 887)

        XCTAssertEqual(frames.count, 8)
        XCTAssertEqual(frames[0], SpriteSheetFrame(x: 0, y: 0, width: 443, height: 443))
        XCTAssertEqual(frames[1], SpriteSheetFrame(x: 443, y: 0, width: 444, height: 443))
        XCTAssertEqual(frames[4], SpriteSheetFrame(x: 0, y: 443, width: 443, height: 444))
        XCTAssertEqual(frames[7], SpriteSheetFrame(x: 1330, y: 443, width: 444, height: 444))
    }

    func testRejectsInvalidGridDimensions() {
        XCTAssertThrowsError(
            try SpriteSheetGrid(columns: 0, rows: 2)
        ) { error in
            XCTAssertEqual(
                error as? SpriteSheetGridError,
                .invalidGrid(columns: 0, rows: 2)
            )
        }
    }

    func testRejectsInvalidImageDimensions() throws {
        let grid = try SpriteSheetGrid(columns: 4, rows: 2)

        XCTAssertThrowsError(
            try grid.frames(imageWidth: 0, imageHeight: 800)
        ) { error in
            XCTAssertEqual(
                error as? SpriteSheetGridError,
                .invalidImageSize(width: 0, height: 800)
            )
        }
    }
}
