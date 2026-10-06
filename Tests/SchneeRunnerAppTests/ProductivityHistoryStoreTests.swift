import Foundation
@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

@MainActor
final class ProductivityHistoryStoreTests: XCTestCase {
    func testSaveAndLoadRoundTrip() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let history = ProductivityHistory().appending(makeEntry(title: "Focus"))

        try fixture.store.save(history)

        XCTAssertEqual(try fixture.store.load(), history)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.historyURL.path))
    }

    func testMalformedJSONIsRejectedWithoutRewrite() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(
            at: fixture.historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let malformed = Data("{not-json".utf8)
        try malformed.write(to: fixture.historyURL)

        XCTAssertThrowsError(try fixture.store.load())
        XCTAssertEqual(try Data(contentsOf: fixture.historyURL), malformed)
    }

    func testUnsupportedSchemaIsRejectedWithoutRewrite() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(
            at: fixture.historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let unsupported = Data("{\"schemaVersion\":999,\"entries\":[]}".utf8)
        try unsupported.write(to: fixture.historyURL)

        XCTAssertThrowsError(try fixture.store.load()) { error in
            XCTAssertEqual(
                error as? ProductivityHistoryError,
                .unsupportedSchemaVersion(999)
            )
        }
        XCTAssertEqual(try Data(contentsOf: fixture.historyURL), unsupported)
    }

    func testReplacementFailurePreservesPreviousValidHistory() throws {
        let fixture = try makeFixture()
        defer { fixture.cleanup() }
        let initial = ProductivityHistory().appending(makeEntry(title: "Initial"))
        let replacement = initial.appending(makeEntry(title: "Replacement"))
        try fixture.store.save(initial)

        let failingStore = ProductivityHistoryStore(
            baseDirectory: fixture.baseDirectory,
            fileManager: FileManager.default,
            replaceItem: { _, _ in
                throw HistoryReplacementFailure.expected
            }
        )

        XCTAssertThrowsError(try failingStore.save(replacement)) { error in
            XCTAssertEqual(error as? HistoryReplacementFailure, .expected)
        }
        XCTAssertEqual(try fixture.store.load(), initial)
    }

    private func makeFixture() throws -> HistoryStoreFixture {
        let baseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: baseDirectory,
            withIntermediateDirectories: true
        )
        let historyURL = baseDirectory
            .appendingPathComponent("SchneeRunner", isDirectory: true)
            .appendingPathComponent("Productivity", isDirectory: true)
            .appendingPathComponent("history.json")
        return HistoryStoreFixture(
            baseDirectory: baseDirectory,
            historyURL: historyURL,
            store: ProductivityHistoryStore(
                baseDirectory: baseDirectory,
                fileManager: FileManager.default
            )
        )
    }

    private func makeEntry(title: String) -> ProductivityHistoryEntry {
        ProductivityHistoryEntry(
            id: UUID(),
            kind: .countdownCompleted,
            sourceID: UUID(),
            title: title,
            occurredAt: Date(timeIntervalSince1970: 1_791_331_200)
        )
    }
}

private enum HistoryReplacementFailure: Error, Equatable {
    case expected
}

private struct HistoryStoreFixture {
    let baseDirectory: URL
    let historyURL: URL
    let store: ProductivityHistoryStore

    func cleanup() {
        try? FileManager.default.removeItem(at: baseDirectory)
    }
}
