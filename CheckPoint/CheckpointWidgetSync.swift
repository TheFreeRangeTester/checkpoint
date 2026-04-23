import Foundation
import SwiftData
import UIKit
import WidgetKit

@MainActor
enum CheckpointWidgetSync {
    static func sync(games: [Game]) {
        CheckpointWidgetSnapshotStore.save(makeSnapshot(from: games))
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func sync(using modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Game>()

        guard let games = try? modelContext.fetch(descriptor) else {
            CheckpointWidgetSnapshotStore.save(.empty)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        sync(games: games)
    }

    private static func makeSnapshot(from games: [Game]) -> CheckpointWidgetSnapshot {
        let prioritizedGames = games.sorted { lhs, rhs in
            compare(lhs, rhs) == .orderedDescending
        }

        let recentGames = prioritizedGames.prefix(4).map(makeFeaturedGame(from:))

        guard let featuredGame = recentGames.first else {
            return .empty
        }

        return CheckpointWidgetSnapshot(
            refreshedAt: .now,
            featuredGame: featuredGame,
            recentGames: recentGames
        )
    }

    private static func makeFeaturedGame(from game: Game) -> FeaturedGame {
        let latestNote = game.notes
            .sorted { $0.createdAt > $1.createdAt }
            .first
            .flatMap { note in
                let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
                return nonEmptyValue(trimmed) ?? (note.photoData == nil ? nil : "Photo checkpoint")
            }

        let nextTaskRaw = game.tasks
            .filter { !$0.isDone }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
            .first?
            .text
        let nextTask = nextTaskRaw.flatMap { task in
            nonEmptyValue(task.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let pendingTasksCount = game.tasks.filter { !$0.isDone }.count

        return FeaturedGame(
            id: game.id,
            title: game.title,
            lastPlayedAt: game.lastPlayedAt,
            latestNote: latestNote,
            nextTask: nextTask,
            pendingTasksCount: pendingTasksCount,
            coverImageData: optimizedWidgetImageData(from: game.coverImageData)
        )
    }

    private static func compare(_ lhs: Game, _ rhs: Game) -> ComparisonResult {
        switch (lhs.lastPlayedAt, rhs.lastPlayedAt) {
        case let (left?, right?) where left != right:
            return left < right ? .orderedAscending : .orderedDescending
        case (_?, nil):
            return .orderedDescending
        case (nil, _?):
            return .orderedAscending
        default:
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt ? .orderedAscending : .orderedDescending
            }

            return lhs.id.uuidString < rhs.id.uuidString ? .orderedAscending : .orderedDescending
        }
    }

    private static func nonEmptyValue(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }

    private static func optimizedWidgetImageData(from originalData: Data?) -> Data? {
        guard let originalData,
              let image = UIImage(data: originalData) else {
            return nil
        }

        let maxDimension: CGFloat = 1100
        let maxArea: CGFloat = 2_200_000
        let originalSize = image.size

        guard originalSize.width > 0, originalSize.height > 0 else {
            return nil
        }

        let dimensionScale = min(1, maxDimension / max(originalSize.width, originalSize.height))
        let areaScale = min(1, sqrt(maxArea / (originalSize.width * originalSize.height)))
        let scale = min(dimensionScale, areaScale)
        let targetSize = CGSize(
            width: max(1, floor(originalSize.width * scale)),
            height: max(1, floor(originalSize.height * scale))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        return resizedImage.jpegData(compressionQuality: 0.78)
    }
}
