import XCTest
@testable import CheckPoint

@MainActor
final class CheckpointWidgetSelectionTests: XCTestCase {
    func testConfigurationIncludesActiveGamesBeyondTheFourRecentGames() {
        let games = (0..<7).map { index in
            Game(title: "Game \(index)", lastPlayedAt: Date(timeIntervalSince1970: Double(index)))
        }
        let finished = Game(title: "Finished", completedAt: .now)

        let snapshot = CheckpointWidgetSync.makeSnapshot(from: games + [finished])

        XCTAssertEqual(snapshot.recentGames.count, 4)
        XCTAssertEqual(snapshot.availableQuickCheckpointGames.count, 7)
        XCTAssertFalse(snapshot.availableQuickCheckpointGames.contains { $0.id == finished.id })
        XCTAssertEqual(snapshot.quickCheckpointGame(selectedID: games[0].id)?.id, games[0].id)
    }

    func testFixedGameStaysSelectedWhenAnotherGameIsPlayed() {
        let selected = Game(title: "Hades", lastPlayedAt: Date(timeIntervalSince1970: 1_000))
        let other = Game(title: "Zelda", lastPlayedAt: Date(timeIntervalSince1970: 2_000))
        let snapshot = CheckpointWidgetSync.makeSnapshot(from: [selected, other])

        XCTAssertEqual(snapshot.featuredGame?.id, other.id)
        XCTAssertEqual(snapshot.quickCheckpointGame(selectedID: selected.id)?.id, selected.id)
        XCTAssertEqual(snapshot.quickCheckpointGame(selectedID: nil)?.id, other.id)
    }

    func testEachWidgetCanResolveItsOwnSelectionAndLink() {
        let first = Game(title: "Same title")
        let second = Game(title: "Same title")
        let snapshot = CheckpointWidgetSync.makeSnapshot(from: [first, second])
        let firstWidgetGame = snapshot.quickCheckpointGame(selectedID: first.id)
        let secondWidgetGame = snapshot.quickCheckpointGame(selectedID: second.id)

        XCTAssertEqual(firstWidgetGame?.id, first.id)
        XCTAssertEqual(secondWidgetGame?.id, second.id)
        let url = CheckpointDeepLink.quickCheckpointURL(gameID: secondWidgetGame?.id)
        XCTAssertEqual(CheckpointDeepLink.quickCheckpointRequest(from: url)?.gameID, second.id)
    }

    func testRenamingASelectedGameUsesItsCurrentTitle() {
        let game = Game(title: "Old title")
        let id = game.id
        game.title = "New title"
        let snapshot = CheckpointWidgetSync.makeSnapshot(from: [game])
        XCTAssertEqual(snapshot.quickCheckpointGame(selectedID: id)?.title, "New title")
    }

    func testUnavailableSelectionNeverFallsBackToADifferentGame() {
        let selected = Game(title: "Hades")
        let other = Game(title: "Zelda")
        let deletedSnapshot = CheckpointWidgetSync.makeSnapshot(from: [other])
        XCTAssertNil(deletedSnapshot.quickCheckpointGame(selectedID: selected.id))

        selected.completedAt = .now
        let finishedSnapshot = CheckpointWidgetSync.makeSnapshot(from: [selected, other])
        XCTAssertNil(finishedSnapshot.quickCheckpointGame(selectedID: selected.id))
        XCTAssertEqual(finishedSnapshot.quickCheckpointGame(selectedID: nil)?.id, other.id)
    }

    func testSelectableCatalogSurvivesSnapshotEncoding() throws {
        let games = (0..<6).map { Game(title: "Game \($0)") }
        let original = CheckpointWidgetSync.makeSnapshot(from: games)
        let decoded = try JSONDecoder().decode(CheckpointWidgetSnapshot.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.availableQuickCheckpointGames.count, 6)
        XCTAssertEqual(decoded.quickCheckpointGame(selectedID: games[5].id)?.title, games[5].title)
    }

    func testLegacySnapshotWithoutCatalogStillLoadsAndOffersRecentGames() throws {
        let game = Game(title: "Legacy")
        let snapshot = CheckpointWidgetSync.makeSnapshot(from: [game])
        let encoded = try JSONEncoder().encode(snapshot)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "selectableGames")
        let legacy = try JSONDecoder().decode(CheckpointWidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(legacy.availableQuickCheckpointGames.map(\.id), [game.id])
        XCTAssertEqual(legacy.quickCheckpointGame(selectedID: game.id)?.title, game.title)
        XCTAssertNil(CheckpointWidgetSnapshot.empty.quickCheckpointGame(selectedID: nil))
    }
}
