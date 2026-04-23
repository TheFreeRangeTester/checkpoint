import Foundation
import SwiftData

@Model
final class Game {
    var id: UUID
    var title: String
    var createdAt: Date
    var lastPlayedAt: Date?
    var coverImageData: Data?

    @Relationship(deleteRule: .cascade, inverse: \GameNote.game)
    var notes: [GameNote]

    @Relationship(deleteRule: .cascade, inverse: \GameTask.game)
    var tasks: [GameTask]

    @Relationship(deleteRule: .cascade, inverse: \GameResource.game)
    var resources: [GameResource]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        lastPlayedAt: Date? = nil,
        coverImageData: Data? = nil,
        notes: [GameNote] = [],
        tasks: [GameTask] = [],
        resources: [GameResource] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastPlayedAt = lastPlayedAt
        self.coverImageData = coverImageData
        self.notes = notes
        self.tasks = tasks
        self.resources = resources
    }
}

@Model
final class GameNote {
    var id: UUID
    var createdAt: Date
    var text: String
    var photoData: Data?
    var game: Game?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        text: String,
        photoData: Data? = nil,
        game: Game? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.photoData = photoData
        self.game = game
    }
}

@Model
final class GameTask {
    var id: UUID
    var createdAt: Date
    var text: String
    var isDone: Bool
    var game: Game?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        text: String,
        isDone: Bool = false,
        game: Game? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
        self.isDone = isDone
        self.game = game
    }
}

@Model
final class GameResource {
    var id: UUID
    var createdAt: Date
    var title: String
    var urlString: String
    var lastUsedAt: Date?
    var game: Game?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        title: String = "",
        urlString: String,
        lastUsedAt: Date? = nil,
        game: Game? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.urlString = urlString
        self.lastUsedAt = lastUsedAt
        self.game = game
    }
}
