import Foundation

enum CheckpointDeepLink {
    static let scheme = "checkpoint"
    static let libraryURL = URL(string: "\(scheme)://library")!

    static func quickCheckpointURL(gameID: UUID? = nil, photo: Bool = false) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = photo ? "capture" : "quick-checkpoint"
        if let gameID { components.path = "/\(gameID.uuidString.lowercased())" }
        return components.url ?? libraryURL
    }

    static func gameURL(gameID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "game"
        components.path = "/\(gameID.uuidString.lowercased())"
        return components.url ?? libraryURL
    }
}

struct CheckpointWidgetSnapshot: Codable, Sendable {
    let refreshedAt: Date
    let featuredGame: FeaturedGame?
    let recentGames: [FeaturedGame]
    let selectableGames: [CheckpointWidgetGame]?

    init(refreshedAt: Date, featuredGame: FeaturedGame?, recentGames: [FeaturedGame], selectableGames: [CheckpointWidgetGame]? = nil) {
        self.refreshedAt = refreshedAt
        self.featuredGame = featuredGame
        self.recentGames = recentGames
        self.selectableGames = selectableGames
    }

    // Older snapshots can still supply the games they already contain.
    var availableQuickCheckpointGames: [CheckpointWidgetGame] {
        selectableGames ?? recentGames.map { CheckpointWidgetGame(id: $0.id, title: $0.title) }
    }

    func quickCheckpointGame(selectedID: UUID?) -> CheckpointWidgetGame? {
        if let selectedID {
            return availableQuickCheckpointGames.first { $0.id == selectedID }
        }
        return featuredGame.map { CheckpointWidgetGame(id: $0.id, title: $0.title) }
    }

    static let empty = CheckpointWidgetSnapshot(refreshedAt: .now, featuredGame: nil, recentGames: [], selectableGames: [])
}

struct CheckpointWidgetGame: Codable, Sendable, Identifiable {
    let id: UUID
    let title: String
}

struct FeaturedGame: Codable, Sendable {
    let id: UUID
    let title: String
    let lastPlayedAt: Date?
    let latestNote: String?
    let nextTask: String?
    let pendingTasksCount: Int
    let coverImageData: Data?
}

enum CheckpointResumeCopy {
    static let latestNotePrefix = "Last Session"
    static let latestNoteFallback = "No session notes yet."
    static let nextTaskFallback = "Review your last checkpoint"
    static let emptyWidgetTitle = "Resume Session"
    static let emptyWidgetMessage = "Add a game and save a checkpoint to see it here."

    static func pendingTasksSummary(pendingCount: Int) -> String {
        if pendingCount == 0 { return "No pending tasks" }
        if pendingCount == 1 { return "1 pending task" }
        return "\(pendingCount) pending tasks"
    }
}

enum CheckpointActivityFormatter {
    static func lastActivityLabel(for lastPlayedAt: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let lastPlayedAt else { return "No sessions yet" }

        let start = calendar.startOfDay(for: lastPlayedAt)
        let end = calendar.startOfDay(for: now)
        let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)

        if days == 0 { return "Played today" }
        if days == 1 { return "Played yesterday" }
        if days < 7 { return "Played \(days) days ago" }

        let weeks = max(1, days / 7)
        if weeks == 1 { return "Played 1 week ago" }
        return "Played \(weeks) weeks ago"
    }

    static func compactLastActivityLabel(for lastPlayedAt: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        guard let lastPlayedAt else { return "No session" }

        let start = calendar.startOfDay(for: lastPlayedAt)
        let end = calendar.startOfDay(for: now)
        let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)

        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days < 7 { return "\(days)d ago" }

        let weeks = max(1, days / 7)
        return "\(weeks)w ago"
    }
}

enum CheckpointWidgetSnapshotStore {
    private static let snapshotKey = "checkpoint.widget.resumeSnapshot"
    private static let appGroupIdentifier = "group.Capybarista.CheckPoint"

    static func load() -> CheckpointWidgetSnapshot {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: snapshotKey) else {
            return .empty
        }

        do {
            return try JSONDecoder().decode(CheckpointWidgetSnapshot.self, from: data)
        } catch {
            return .empty
        }
    }
}
