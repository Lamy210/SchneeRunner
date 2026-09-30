@testable import SchneeRunnerCore
import XCTest

final class AnimatedImageLoaderTests: XCTestCase {
    func testLoadsAPNGWithAuthoredDurations() throws {
        let fixture = try makeFixture(
            fileName: "runner.png",
            base64: Self.apngBase64
        )
        defer { fixture.cleanup() }

        let animation = try AnimatedImageLoader(
            format: .apng
        ).load(from: fixture.url)

        XCTAssertEqual(animation.frames.count, 2)
        XCTAssertEqual(
            animation.schedule.frameDurations[0],
            0.05,
            accuracy: 0.01
        )
        XCTAssertEqual(
            animation.schedule.frameDurations[1],
            0.2,
            accuracy: 0.01
        )
    }

    func testLoadsAnimatedWebPWithAuthoredDurations() throws {
        let fixture = try makeFixture(
            fileName: "runner.webp",
            base64: Self.webPBase64
        )
        defer { fixture.cleanup() }

        let animation = try AnimatedImageLoader(
            format: .webP
        ).load(from: fixture.url)

        XCTAssertEqual(animation.frames.count, 2)
        XCTAssertEqual(
            animation.schedule.frameDurations[0],
            0.05,
            accuracy: 0.01
        )
        XCTAssertEqual(
            animation.schedule.frameDurations[1],
            0.2,
            accuracy: 0.01
        )
    }

    func testRejectsStaticPNGAsAPNG() throws {
        let fixture = try makeFixture(
            fileName: "static.png",
            base64: Self.staticPNGBase64
        )
        defer { fixture.cleanup() }

        XCTAssertThrowsError(
            try AnimatedImageLoader(
                format: .apng
            ).load(from: fixture.url)
        ) { error in
            XCTAssertEqual(
                error as? AnimatedImageLoaderError,
                .insufficientFrames(actual: 1)
            )
        }
    }

    func testRejectsAPNGWhenWebPExpected() throws {
        let fixture = try makeFixture(
            fileName: "spoofed.webp",
            base64: Self.apngBase64
        )
        defer { fixture.cleanup() }

        XCTAssertThrowsError(
            try AnimatedImageLoader(
                format: .webP
            ).load(from: fixture.url)
        ) { error in
            guard case let .unsupportedContentType(
                expected,
                actual
            ) = error as? AnimatedImageLoaderError else {
                return XCTFail("Expected content-type rejection.")
            }

            XCTAssertEqual(
                expected,
                "org.webmproject.webp"
            )
            XCTAssertEqual(
                actual,
                "public.png"
            )
        }
    }

    func testRejectsAggregatePixelBudgetBeforeDecode() throws {
        let fixture = try makeFixture(
            fileName: "runner.png",
            base64: Self.apngBase64
        )
        defer { fixture.cleanup() }

        let loader = AnimatedImageLoader(
            format: .apng,
            policy: AnimatedImagePolicy(
                maximumTotalPixelCount: 7
            )
        )

        XCTAssertThrowsError(
            try loader.load(from: fixture.url)
        ) { error in
            XCTAssertEqual(
                error as? AnimatedImageLoaderError,
                .totalPixelCountTooLarge(
                    actual: 8,
                    maximum: 7
                )
            )
        }
    }

    private func makeFixture(
        fileName: String,
        base64: String
    ) throws -> AnimatedImageFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let data = try XCTUnwrap(
            Data(base64Encoded: base64)
        )
        let url = directory.appendingPathComponent(fileName)
        try data.write(to: url)

        return AnimatedImageFixture(
            directory: directory,
            url: url
        )
    }

    private static let apngBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAYAAABytg0kAAAACGFjVEwAAAACAAAA" +
        "APONk3AAAAAaZmNUTAAAAAAAAAACAAAAAgAAAAAAAAAAAAEAFAAA/uxSegAAABRJ" +
        "REFUeJxj/M/A8J+BgYGBiQEKAB8XAgJPlM6+AAAAGmZjVEwAAAABAAAAAgAAAAIA" +
        "AAAAAAAAAAABAAUAAHh7cekAAAAYZmRBVAAAAAJ4nGNk+M/wn4GBgYGJAQoAHhgC" +
        "AjJqffAAAAAASUVORK5CYII="

    private static let webPBase64 =
        "UklGRoQAAABXRUJQVlA4WAoAAAACAAAAAQAAAQAAQU5JTQYAAAAAAAAAAABBTk1G" +
        "KAAAAAAAAAAAAAEAAAEAADIAAAJWUDhMDwAAAC8BQAAABxD9j/4HIqL/AQBBTk1G" +
        "KAAAAAAAAAAAAAEAAAEAAMgAAABWUDhMDwAAAC8BQAAAB9D/iP4HIqL/AQA="

    private static let staticPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk" +
        "+A8AAQUBAScY42YAAAAASUVORK5CYII="
}

private struct AnimatedImageFixture {
    let directory: URL
    let url: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directory)
    }
}
