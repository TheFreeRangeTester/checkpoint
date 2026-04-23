import Foundation

enum CheckpointDeepLink {
    static let scheme = "checkpoint"
    static let libraryURL = URL(string: "\(scheme)://library")!

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

    static let empty = CheckpointWidgetSnapshot(refreshedAt: .now, featuredGame: nil, recentGames: [])
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
    static let latestNotePrefix = "Latest note"
    static let latestNoteFallback = "No checkpoints yet. Add one before you jump back in."
    static let nextTaskFallback = "Ready to jump back in."
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
