import AppIntents
import Foundation

struct QuickCheckpointGameEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Game"
    static let defaultQuery = QuickCheckpointGameQuery()
    static let automaticID = "last-played"
    static let automatic = QuickCheckpointGameEntity(id: automaticID, title: "Last Played Game")

    let id: String
    let title: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    var gameID: UUID? { UUID(uuidString: id) }

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }

    init(game: CheckpointWidgetGame) {
        id = game.id.uuidString
        title = game.title
    }
}

struct QuickCheckpointGameQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [QuickCheckpointGameEntity] {
        let games = await CheckpointWidgetSnapshotStore.load().availableQuickCheckpointGames
        return identifiers.map { id in
            if id == QuickCheckpointGameEntity.automaticID { return .automatic }
            if let game = games.first(where: { $0.id == UUID(uuidString: id) }) {
                return QuickCheckpointGameEntity(game: game)
            }
            // Preserve a removed selection so the widget never silently switches games.
            return QuickCheckpointGameEntity(id: id, title: "Game Unavailable")
        }
    }

    func suggestedEntities() async throws -> [QuickCheckpointGameEntity] {
        let games = await CheckpointWidgetSnapshotStore.load().availableQuickCheckpointGames
        return [.automatic] + games.map(QuickCheckpointGameEntity.init(game:))
    }

    func entities(matching string: String) async throws -> [QuickCheckpointGameEntity] {
        let games = try await suggestedEntities()
        return string.isEmpty ? games : games.filter { $0.title.localizedStandardContains(string) }
    }

    func defaultResult() async -> QuickCheckpointGameEntity? { .automatic }
}

struct QuickCheckpointConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Quick Checkpoint"
    static let description = IntentDescription("Choose a game for this widget, or follow your last played game.")

    @Parameter(title: "Game")
    var game: QuickCheckpointGameEntity?

    static var parameterSummary: some ParameterSummary {
        Summary { \.$game }
    }
}
