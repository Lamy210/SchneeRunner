import Foundation
@testable import VisualDiffCore
import XCTest

final class VisualApprovalTests: XCTestCase {
    func testImageDigestUsesStablePrefixedLowercaseSHA256() {
        XCTAssertEqual(
            ImageDigest.sha256(Data("abc".utf8)),
            "sha256:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func testValidApprovalDecodes() throws {
        let approval = try VisualApproval.decode(Data(validApproval.utf8))

        XCTAssertEqual(approval.schemaVersion, 1)
        XCTAssertEqual(approval.caseID, "settings-light")
        XCTAssertEqual(approval.profileFingerprint, "profile-v1")
        XCTAssertEqual(approval.reason, "Redesigned settings sidebar")
    }

    func testLoadRejectsOversizedApprovalFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let url = directory.appendingPathComponent("approval.json")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let oversized = validApproval
            + String(repeating: " ", count: 70 * 1024)
        try Data(oversized.utf8).write(to: url)

        XCTAssertThrowsError(try VisualApproval.load(from: url))
    }

    func testLoadRejectsSymlinkedApprovalFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let targetURL = directory.appendingPathComponent("outside.json")
        let approvalURL = directory.appendingPathComponent("approval.json")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try Data(validApproval.utf8).write(to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: approvalURL,
            withDestinationURL: targetURL
        )

        XCTAssertThrowsError(try VisualApproval.load(from: approvalURL))
    }

    func testRejectsUnsupportedSchemaVersion() {
        assertApprovalFails(validApproval.replacingOccurrences(
            of: "\"schemaVersion\": 1",
            with: "\"schemaVersion\": 2"
        ))
    }

    func testRejectsEmptyReason() {
        assertApprovalFails(validApproval.replacingOccurrences(
            of: "\"reason\": \"Redesigned settings sidebar\"",
            with: "\"reason\": \"   \""
        ))
    }

    func testRejectsMalformedDigest() {
        assertApprovalFails(validApproval.replacingOccurrences(
            of: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            with: "sha256:not-a-digest"
        ))
    }

    func testExactMatchRequiresEveryIdentityField() throws {
        let approval = try VisualApproval.decode(Data(validApproval.utf8))
        let context = VisualApprovalContext(
            caseID: "settings-light",
            fromDigest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            toDigest: "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            profileFingerprint: "profile-v1"
        )

        XCTAssertTrue(approval.matches(context))
        XCTAssertFalse(approval.matches(.init(
            caseID: "settings-dark",
            fromDigest: context.fromDigest,
            toDigest: context.toDigest,
            profileFingerprint: context.profileFingerprint
        )))
        XCTAssertFalse(approval.matches(.init(
            caseID: context.caseID,
            fromDigest: "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc",
            toDigest: context.toDigest,
            profileFingerprint: context.profileFingerprint
        )))
        XCTAssertFalse(approval.matches(.init(
            caseID: context.caseID,
            fromDigest: context.fromDigest,
            toDigest: "sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd",
            profileFingerprint: context.profileFingerprint
        )))
        XCTAssertFalse(approval.matches(.init(
            caseID: context.caseID,
            fromDigest: context.fromDigest,
            toDigest: context.toDigest,
            profileFingerprint: "profile-v2"
        )))
    }

    private func assertApprovalFails(
        _ json: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try VisualApproval.decode(Data(json.utf8)),
            file: file,
            line: line
        )
    }

    private var validApproval: String {
        """
        {
          "schemaVersion": 1,
          "caseId": "settings-light",
          "fromDigest": "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "toDigest": "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "profileFingerprint": "profile-v1",
          "reason": "Redesigned settings sidebar"
        }
        """
    }
}
