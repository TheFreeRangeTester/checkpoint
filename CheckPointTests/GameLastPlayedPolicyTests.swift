import XCTest
@testable import CheckPoint

final class GameLastPlayedPolicyTests: XCTestCase {
    func testLastPlayedUpdatesWhenResuming() {
        let previousDate = Date(timeIntervalSince1970: 1_000)
        let resumedAt = Date(timeIntervalSince1970: 2_000)

        let updated = GameLastPlayedPolicy.updatedValue(
            for: previousDate,
            action: .resume,
            now: resumedAt
        )

        XCTAssertEqual(updated, resumedAt)
    }

    func testLastPlayedDoesNotChangeWhenAddingOrEditingNotes() {
        let previousDate = Date(timeIntervalSince1970: 1_000)
        let otherDate = Date(timeIntervalSince1970: 2_000)

        XCTAssertEqual(
            GameLastPlayedPolicy.updatedValue(for: previousDate, action: .addNote, now: otherDate),
            previousDate
        )
        XCTAssertEqual(
            GameLastPlayedPolicy.updatedValue(for: previousDate, action: .editNote, now: otherDate),
            previousDate
        )
    }

    func testLastPlayedDoesNotChangeWhenAddingEditingOrCompletingTasks() {
        let previousDate = Date(timeIntervalSince1970: 1_000)
        let otherDate = Date(timeIntervalSince1970: 2_000)

        XCTAssertEqual(
            GameLastPlayedPolicy.updatedValue(for: previousDate, action: .addTask, now: otherDate),
            previousDate
        )
        XCTAssertEqual(
            GameLastPlayedPolicy.updatedValue(for: previousDate, action: .editTask, now: otherDate),
            previousDate
        )
        XCTAssertEqual(
            GameLastPlayedPolicy.updatedValue(for: previousDate, action: .completeTask, now: otherDate),
            previousDate
        )
    }
}
