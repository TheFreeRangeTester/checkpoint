import XCTest
import SwiftData
@testable import CheckPoint

@MainActor
final class CheckpointPolicyTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(
            for: Game.self, GameNote.self, GameTask.self, GameResource.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    func testCheckpointPersistsSummaryAndPrioritizesNewObjectiveWithoutFinishingOldTasks() throws {
        let container = try container()
        let context = container.mainContext
        let lastPlayed = Date(timeIntervalSince1970: 1_000)
        let game = Game(title: "Hades", lastPlayedAt: lastPlayed)
        context.insert(game)
        let oldTask = GameTask(createdAt: .distantPast, text: "Find a keepsake", game: game)
        context.insert(oldTask)
        game.tasks.append(oldTask)

        try CheckpointPolicy.save(
            for: game, summary: "  Beat the boss  ", objective: "  Northern city  ",
            photoData: nil, pin: false, in: context
        )

        let reloadedContext = ModelContext(container)
        let saved = try XCTUnwrap(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        XCTAssertEqual(saved.notes.count, 1)
        XCTAssertEqual(saved.notes.first?.text, "Beat the boss")
        XCTAssertEqual(saved.notes.first?.kind, .sessionWrapUp)
        XCTAssertEqual(CheckpointPolicy.pendingTasks(for: saved).map(\.text), ["Northern city", "Find a keepsake"])
        XCTAssertFalse(oldTask.isDone)
        XCTAssertEqual(saved.lastPlayedAt, lastPlayed)
        XCTAssertNil(saved.completedAt)
    }

    func testPhotoOnlyCheckpointPersistsWithoutTextAndCanBePinned() throws {
        let container = try container()
        let context = container.mainContext
        let game = Game(title: "Zelda")
        context.insert(game)
        let data = Data([1, 2, 3])
        let now = Date(timeIntervalSince1970: 2_000)

        try CheckpointPolicy.save(for: game, summary: " \n ", objective: "", photoData: data, pin: true, in: context, now: now)

        let reloadedContext = ModelContext(container)
        let saved = try XCTUnwrap(reloadedContext.fetch(FetchDescriptor<Game>()).first)
        XCTAssertEqual(saved.notes.count, 1)
        XCTAssertEqual(saved.notes.first?.photoData, data)
        XCTAssertEqual(saved.notes.first?.text, "")
        XCTAssertEqual(saved.notes.first?.pinnedAt, now)
        XCTAssertEqual(saved.notes.first?.kind, .sessionWrapUp)
        XCTAssertTrue(saved.tasks.isEmpty)
        XCTAssertNil(saved.lastPlayedAt)
    }

    func testObjectiveOnlyCheckpointKeepsPreviousSummary() throws {
        let container = try container()
        let context = container.mainContext
        let game = Game(title: "Outer Wilds")
        context.insert(game)
        try CheckpointPolicy.save(for: game, summary: "Found a signal", objective: "", photoData: nil, pin: false, in: context)
        try CheckpointPolicy.save(for: game, summary: "", objective: "Follow the signal", photoData: nil, pin: false, in: context)

        XCTAssertEqual(game.notes.count, 1)
        XCTAssertEqual(game.notes.first?.text, "Found a signal")
        XCTAssertEqual(CheckpointPolicy.pendingTasks(for: game).first?.text, "Follow the signal")
    }

    func testBlankCheckpointDoesNotCreateAnything() throws {
        let container = try container()
        let game = Game(title: "Cocoon")
        container.mainContext.insert(game)
        try CheckpointPolicy.save(for: game, summary: " \n", objective: " ", photoData: nil, pin: true, in: container.mainContext)
        XCTAssertTrue(game.notes.isEmpty)
        XCTAssertTrue(game.tasks.isEmpty)
        XCTAssertFalse(CheckpointPolicy.canSave(summary: " \n", objective: " ", photoData: nil))
    }

    func testCompletingOrDeletingPreferredObjectiveFallsBackToOldestPendingTask() {
        let game = Game(title: "Hades")
        let oldTask = GameTask(createdAt: .distantPast, text: "Old task")
        let next = GameTask(text: "Next task")
        game.tasks = [oldTask, next]
        game.nextObjectiveID = next.id
        next.isDone = true
        XCTAssertEqual(CheckpointPolicy.pendingTasks(for: game).map(\.id), [oldTask.id])
        game.tasks.removeAll { $0.id == next.id }
        XCTAssertEqual(CheckpointPolicy.pendingTasks(for: game).first?.id, oldTask.id)
    }

    func testCheckpointDoesNotReactivateFinishedGame() throws {
        let container = try container()
        let completedAt = Date(timeIntervalSince1970: 1_000)
        let game = Game(title: "Cocoon", completedAt: completedAt)
        container.mainContext.insert(game)
        try CheckpointPolicy.save(for: game, summary: "Final thoughts", objective: "", photoData: nil, pin: false, in: container.mainContext)
        XCTAssertEqual(game.completedAt, completedAt)
    }

    func testWidgetAndAppAgreeOnTheNewObjectiveAndPhotoSummary() throws {
        let container = try container()
        let game = Game(title: "Zelda")
        container.mainContext.insert(game)
        let old = GameTask(createdAt: .distantPast, text: "Old objective", game: game)
        container.mainContext.insert(old)
        game.tasks.append(old)
        try CheckpointPolicy.save(for: game, summary: "", objective: "Northern city", photoData: Data([1]), pin: true, in: container.mainContext)
        let finished = Game(title: "Finished", lastPlayedAt: .distantFuture, completedAt: .now)

        let snapshot = CheckpointWidgetSync.makeSnapshot(from: [finished, game])

        XCTAssertEqual(snapshot.featuredGame?.id, game.id)
        XCTAssertEqual(snapshot.featuredGame?.nextTask, CheckpointPolicy.pendingTasks(for: game).first?.text)
        XCTAssertEqual(snapshot.featuredGame?.nextTask, "Northern city")
        XCTAssertEqual(snapshot.featuredGame?.latestNote, "Photo checkpoint")
        XCTAssertEqual(snapshot.featuredGame?.pendingTasksCount, 2)
        XCTAssertEqual(snapshot.recentGames.map(\.id), [game.id])
    }

    func testBackupRoundTripPreservesNextObjectiveAndPhotoCheckpoint() throws {
        let container = try container()
        let game = Game(title: "Zelda")
        container.mainContext.insert(game)
        try CheckpointPolicy.save(for: game, summary: "Map", objective: "Go north", photoData: Data([1]), pin: true, in: container.mainContext)
        let backup = CheckpointBackup.from(games: [game])
        let restored = try CheckpointBackup.decode(from: backup.jsonData())
        let snapshot = try XCTUnwrap(restored.games.first)
        XCTAssertEqual(snapshot.nextObjectiveID, game.nextObjectiveID)
        XCTAssertTrue(snapshot.tasks.contains { $0.id == snapshot.nextObjectiveID })
        XCTAssertEqual(snapshot.notes.first?.photoData, Data([1]))
        XCTAssertNotNil(snapshot.notes.first?.pinnedAt)
    }

    func testOlderBackupsWithoutPreferredObjectiveStillDecode() throws {
        let oldBackup = """
        {"schemaVersion":1,"exportedAt":"2026-01-01T00:00:00Z","games":[{
        "id":"00000000-0000-0000-0000-000000000001","title":"Legacy",
        "createdAt":"2026-01-01T00:00:00Z","notes":[],"tasks":[]}]}
        """
        let backup = try CheckpointBackup.decode(from: Data(oldBackup.utf8))
        XCTAssertTrue(CheckpointBackup.supportedSchemaVersions.contains(backup.schemaVersion))
        XCTAssertNil(backup.games.first?.nextObjectiveID)
        XCTAssertNil(backup.games.first?.completedAt)
        XCTAssertEqual(backup.games.first?.resources.count, 0)
    }
}
