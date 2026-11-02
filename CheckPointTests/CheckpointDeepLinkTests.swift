import XCTest
@testable import CheckPoint

final class CheckpointDeepLinkTests: XCTestCase {
    func testWidgetQuickCheckpointLinkKeepsGameID() throws {
        let id = UUID()
        let url = CheckpointDeepLink.quickCheckpointURL(gameID: id)
        let request = try XCTUnwrap(CheckpointDeepLink.quickCheckpointRequest(from: url))
        XCTAssertEqual(request.gameID, id)
        XCTAssertFalse(request.startsWithPhoto)
        XCTAssertNil(CheckpointDeepLink.gameID(from: url))
    }

    func testScreenshotLinkOpensPhotoFirst() throws {
        let id = UUID()
        let request = try XCTUnwrap(CheckpointDeepLink.quickCheckpointRequest(from: CheckpointDeepLink.quickCheckpointURL(gameID: id, photo: true)))
        XCTAssertEqual(request.gameID, id)
        XCTAssertTrue(request.startsWithPhoto)
    }

    func testShortcutCanUseMostRecentGameWithoutAnID() throws {
        let request = try XCTUnwrap(CheckpointDeepLink.quickCheckpointRequest(from: URL(string: "checkpoint://quick-checkpoint")!))
        XCTAssertNil(request.gameID)
        XCTAssertFalse(request.startsWithPhoto)
    }

    func testInvalidTargetsAreRejectedAndResumeLinkStillWorks() {
        for raw in ["https://quick-checkpoint", "checkpoint://quick-checkpoint/not-a-uuid", "checkpoint://capture/a/b", "checkpoint://library"] {
            XCTAssertNil(CheckpointDeepLink.quickCheckpointRequest(from: URL(string: raw)!))
        }
        let id = UUID()
        XCTAssertEqual(CheckpointDeepLink.gameID(from: CheckpointDeepLink.gameURL(gameID: id)), id)
    }
}
