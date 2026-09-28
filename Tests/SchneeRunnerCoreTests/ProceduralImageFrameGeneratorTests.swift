import AppKit
@testable import SchneeRunnerCore
import XCTest

final class ProceduralImageFrameGeneratorTests: XCTestCase {
    func testGeneratesEightConsistentFramesFromSingleImage() throws {
        let source = makeSourceImage()
        let generator = ProceduralImageFrameGenerator(outputHeight: 64)

        let frames = try generator.frames(from: source)

        XCTAssertEqual(frames.count, 8)
        let firstSize = try XCTUnwrap(frames.first?.size)
        XCTAssertEqual(firstSize.height, 64)
        XCTAssertTrue(frames.allSatisfy { $0.size == firstSize })
        XCTAssertTrue(
            frames.allSatisfy { image in
                image.representations.contains { $0 is NSBitmapImageRep }
            }
        )
    }

    func testRejectsZeroSizedImage() {
        let generator = ProceduralImageFrameGenerator()

        XCTAssertThrowsError(
            try generator.frames(from: NSImage(size: .zero))
        ) { error in
            XCTAssertEqual(
                error as? ProceduralImageFrameGeneratorError,
                .invalidSourceSize
            )
        }
    }

    private func makeSourceImage() -> NSImage {
        NSImage(
            size: NSSize(width: 32, height: 32),
            flipped: false
        ) { rect in
            NSColor.white.setFill()
            NSBezierPath(rect: rect).fill()
            return true
        }
    }
}
