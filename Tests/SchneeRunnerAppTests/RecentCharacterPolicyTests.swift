@testable import SchneeRunnerApp
import SchneeRunnerCore
import XCTest

final class RecentCharacterPolicyTests: XCTestCase {
    func testExcludesUnavailableAssetsWhilePreservingOrder() {
        let first = makeAsset(id: UUID())
        let unavailable = makeAsset(id: UUID())
        let third = makeAsset(id: UUID())

        let result = RecentCharacterPolicy.availableAssets(
            [first, unavailable, third],
            excluding: [unavailable.id]
        )

        XCTAssertEqual(result.map(\.id), [first.id, third.id])
    }

    func testReturnsAllAssetsWhenNothingIsExcluded() {
        let first = makeAsset(id: UUID())
        let second = makeAsset(id: UUID())

        let result = RecentCharacterPolicy.availableAssets(
            [first, second],
            excluding: []
        )

        XCTAssertEqual(result.map(\.id), [first.id, second.id])
    }

    private func makeAsset(id: UUID) -> StoredCharacterAsset {
        StoredCharacterAsset(
            id: id,
            displayName: id.uuidString,
            kind: .singleImage,
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }
}
