import Foundation
import SwiftData

enum CheckpointPolicy {
    static func pendingTasks(for game: Game) -> [GameTask] {
        game.tasks.filter { !$0.isDone }.sorted { lhs, rhs in
            if (lhs.id == game.nextObjectiveID) != (rhs.id == game.nextObjectiveID) {
                return lhs.id == game.nextObjectiveID
            }
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func canSave(summary: String, objective: String, photoData: Data?) -> Bool {
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoData != nil
    }

    /// A checkpoint records context; it does not start a playing session or finish old tasks.
    static func save(
        for game: Game,
        summary: String,
        objective: String,
        photoData: Data?,
        pin: Bool,
        in context: ModelContext,
        now: Date = .now
    ) throws {
        let summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let objective = objective.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSave(summary: summary, objective: objective, photoData: photoData) else { return }
        let previousObjectiveID = game.nextObjectiveID
        var newNote: GameNote?
        var newTask: GameTask?

        if !summary.isEmpty || photoData != nil {
            let note = GameNote(
                createdAt: now, text: summary, photoData: photoData,
                kind: .sessionWrapUp, pinnedAt: pin ? now : nil, game: game
            )
            context.insert(note)
            game.notes.append(note)
            newNote = note
        }
        if !objective.isEmpty {
            let task = GameTask(createdAt: now, text: objective, game: game)
            context.insert(task)
            game.tasks.append(task)
            game.nextObjectiveID = task.id
            newTask = task
        }

        do {
            try context.save()
        } catch {
            if let newNote {
                game.notes.removeAll { $0.id == newNote.id }
                context.delete(newNote)
            }
            if let newTask {
                game.tasks.removeAll { $0.id == newTask.id }
                context.delete(newTask)
            }
            game.nextObjectiveID = previousObjectiveID
            throw error
        }
    }
}
