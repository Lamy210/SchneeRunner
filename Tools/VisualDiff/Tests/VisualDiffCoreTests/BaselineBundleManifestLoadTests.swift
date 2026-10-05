import Foundation
@testable import VisualDiffCore
import XCTest

final class BaselineBundleManifestLoadTests: XCTestCase {
    func testLoadRejectsOversizedManifestFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let manifest = makeManifest()
        var data = try JSONEncoder().encode(manifest)
        data.append(Data(repeating: 0x20, count: 70 * 1024))
        let url = root.appendingPathComponent("bundle-manifest.json")
        try data.write(to: url)

        XCTAssertThrowsError(
            try BaselineBundleManifest.load(from: url)
        ) { error in
            guard case let BaselineBundleError.fileTooLarge(
                actualBytes,
                maximumBytes
            ) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertGreaterThan(actualBytes, maximumBytes)
            XCTAssertEqual(maximumBytes, 64 * 1024)
        }
    }

    func testLoadRejectsSymlinkedManifestFile() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

        let targetURL = root.appendingPathComponent("outside.json")
        let manifestURL = root.appendingPathComponent("bundle-manifest.json")
        try JSONEncoder().encode(makeManifest()).write(to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: manifestURL,
            withDestinationURL: targetURL
        )

        XCTAssertThrowsError(
            try BaselineBundleManifest.load(from: manifestURL)
        )
    }

    private func makeManifest() -> BaselineBundleManifest {
        BaselineBundleManifest(
            schemaVersion: 1,
            sourceRepository: "Lamy210/template",
            workflow: "visual-regression.yml",
            sourceRunID: "12345",
            runAttempt: 1,
            sourceSHA: "0123456789abcdef0123456789abcdef01234567",
            profileFingerprint: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            previousBaselineReference: nil,
            cases: []
        )
    }
}
