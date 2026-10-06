import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityStateStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let snapshot = try ProductivitySnapshot(
            timers: [makeTimer(title: "Focus")]
        )

        try fixture.store.save(snapshot)

        XCTAssertEqual(try fixture.store.load(), snapshot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.stateURL.path))
    }

    func testMalformedJSONIsRejectedWithoutRewrite() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(
            at: fixture.stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let malformed = Data("{not-json".utf8)
        try malformed.write(to: fixture.stateURL)

        XCTAssertThrowsError(try fixture.store.load())
        XCTAssertEqual(try Data(contentsOf: fixture.stateURL), malformed)
    }

    func testUnsupportedSchemaIsRejectedWithoutRewrite() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(
            at: fixture.stateURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let unsupported = try XCTUnwrap(
            "{\"schemaVersion\":999,\"timers\":[]}".data(using: .utf8)
        )
        try unsupported.write(to: fixture.stateURL)

        XCTAssertThrowsError(try fixture.store.load()) { error in
            XCTAssertEqual(
                error as? ProductivitySnapshotError,
                .unsupportedSchemaVersion(999)
            )
        }
        XCTAssertEqual(try Data(contentsOf: fixture.stateURL), unsupported)
    }

    func testReplacementFailurePreservesPreviousValidState() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let initial = try ProductivitySnapshot(
            timers: [makeTimer(title: "Initial")]
        )
        let replacement = try ProductivitySnapshot(
            timers: [makeTimer(title: "Replacement")]
        )
        try fixture.store.save(initial)

        let failingStore = ProductivityStateStore(
            baseDirectory: fixture.baseDirectory,
            fileManager: FileManager.default,
            replaceItem: { _, _ in
                throw ReplacementFailure.expected
            }
        )

        XCTAssertThrowsError(try failingStore.save(replacement)) { error in
            XCTAssertEqual(error as? ReplacementFailure, .expected)
        }
        XCTAssertEqual(try fixture.store.load(), initial)
    }

    private func makeFixture() throws -> StoreFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let stateURL = baseDirectory
            .appendingPathComponent("SchneeRunner", isDirectory: true)
            .appendingPathComponent("Productivity", isDirectory: true)
            .appendingPathComponent("state.json")
        return StoreFixture(
            baseDirectory: baseDirectory,
            stateURL: stateURL,
            store: ProductivityStateStore(
                baseDirectory: baseDirectory,
                fileManager: FileManager.default
            )
        )
    }

    private func makeTimer(title: String) throws -> ProductivityCountdownTimer {
        try ProductivityCountdownTimer(
            id: UUID(),
            title: title,
            duration: 60,
            startedAt: Date(timeIntervalSince1970: 1_791_331_200)
        )
    }
}

private enum ReplacementFailure: Error, Equatable {
    case expected
}

private struct StoreFixture {
    let baseDirectory: URL
    let stateURL: URL
    let store: ProductivityStateStore

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
