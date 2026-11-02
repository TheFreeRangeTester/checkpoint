import AppIntents
import SwiftUI
import WidgetKit

struct QuickCheckpointEntry: TimelineEntry {
    let date: Date
    let game: CheckpointWidgetGame?
    let hasUnavailableSelection: Bool

    var url: URL {
        hasUnavailableSelection ? CheckpointDeepLink.libraryURL : CheckpointDeepLink.quickCheckpointURL(gameID: game?.id)
    }
}

struct QuickCheckpointProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickCheckpointEntry {
        QuickCheckpointEntry(date: .now, game: CheckpointWidgetGame(id: UUID(), title: "Elden Ring"), hasUnavailableSelection: false)
    }

    func snapshot(for configuration: QuickCheckpointConfiguration, in context: Context) async -> QuickCheckpointEntry {
        let current = entry(for: configuration)
        if context.isPreview && current.game == nil && !current.hasUnavailableSelection {
            return placeholder(in: context)
        }
        return current
    }

    func timeline(for configuration: QuickCheckpointConfiguration, in context: Context) async -> Timeline<QuickCheckpointEntry> {
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(1800)))
    }

    private func entry(for configuration: QuickCheckpointConfiguration) -> QuickCheckpointEntry {
        let snapshot = CheckpointWidgetSnapshotStore.load()
        let selectedID = configuration.game?.gameID
        let game = snapshot.quickCheckpointGame(selectedID: selectedID)
        return QuickCheckpointEntry(date: .now, game: game, hasUnavailableSelection: selectedID != nil && game == nil)
    }
}

/// Each copy keeps its own choice through WidgetKit's Edit Widget configuration.
struct QuickCheckpointWidget: Widget {
    let kind = "QuickCheckpointWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickCheckpointConfiguration.self, provider: QuickCheckpointProvider()) { entry in
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "plus.bubble.fill")
                    .font(.title)
                    .foregroundStyle(.cyan)
                Spacer(minLength: 0)
                Text("QUICK CHECKPOINT")
                    .font(.headline.weight(.black))
                    .fontWidth(.condensed)
                Text(entry.hasUnavailableSelection ? "Game unavailable" : entry.game?.title ?? "Choose a game")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if entry.hasUnavailableSelection {
                    Text("Edit Widget to choose another")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) {
                Color(red: 0.05, green: 0.08, blue: 0.13)
            }
            .widgetURL(entry.url)
        }
        .configurationDisplayName("Quick Checkpoint")
        .description("Save a sentence or screenshot. Touch and hold to choose a game in Edit Widget.")
        .supportedFamilies([.systemSmall])
    }
}
