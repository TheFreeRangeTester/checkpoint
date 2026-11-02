import XCTest
@testable import CheckPoint

final class GameCompletionPolicyTests: XCTestCase {
    func testMarkFinishedRecordsTheCompletionDateWithoutChangingGameContent() {
        let completionDate = Date(timeIntervalSince1970: 2_000)
        let game = Game(title: "Outer Wilds")
        let task = GameTask(text: "Visit the Quantum Moon", game: game)
        game.tasks.append(task)

        GameCompletionPolicy.markFinished(game, at: completionDate)

        XCTAssertEqual(game.completedAt, completionDate)
        XCTAssertEqual(game.tasks.count, 1)
        XCTAssertFalse(game.tasks[0].isDone)
    }

    func testMarkActiveClearsTheCompletionDate() {
        let game = Game(title: "Outer Wilds", completedAt: Date(timeIntervalSince1970: 2_000))

        GameCompletionPolicy.markActive(game)

        XCTAssertNil(game.completedAt)
    }

    func testActiveGamesExcludesFinishedGames() {
        let active = Game(title: "Hades")
        let finished = Game(title: "Cocoon", completedAt: Date(timeIntervalSince1970: 2_000))

        let result = GameCompletionPolicy.activeGames(from: [finished, active])

        XCTAssertEqual(result.map(\.id), [active.id])
    }
}
