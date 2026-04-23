import Foundation

enum GameLastPlayedAction {
    case resume
    case addNote
    case editNote
    case addTask
    case editTask
    case completeTask
}

enum GameLastPlayedPolicy {
    static func updatedValue(
        for currentValue: Date?,
        action: GameLastPlayedAction,
        now: Date = .now
    ) -> Date? {
        switch action {
        case .resume:
            return now
        case .addNote, .editNote, .addTask, .editTask, .completeTask:
            return currentValue
        }
    }
}
