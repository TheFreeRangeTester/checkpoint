import Foundation

enum GameCompletionPolicy {
    static func markFinished(_ game: Game, at date: Date = .now) {
        game.completedAt = date
    }

    static func markActive(_ game: Game) {
        game.completedAt = nil
    }

    static func activeGames(from games: [Game]) -> [Game] {
        games.filter { $0.completedAt == nil }
    }
}
