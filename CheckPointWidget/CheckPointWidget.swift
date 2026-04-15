import SwiftUI
import UIKit
import WidgetKit

struct CheckPointResumeEntry: TimelineEntry {
    let date: Date
    let snapshot: CheckpointWidgetSnapshot
}

struct CheckPointResumeProvider: TimelineProvider {
    func placeholder(in context: Context) -> CheckPointResumeEntry {
        CheckPointResumeEntry(date: .now, snapshot: previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckPointResumeEntry) -> Void) {
        let snapshot = context.isPreview ? previewSnapshot : CheckpointWidgetSnapshotStore.load()
        completion(CheckPointResumeEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckPointResumeEntry>) -> Void) {
        let snapshot = CheckpointWidgetSnapshotStore.load()
        let entry = CheckPointResumeEntry(date: .now, snapshot: snapshot)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private var previewSnapshot: CheckpointWidgetSnapshot {
        CheckpointWidgetSnapshot(
            refreshedAt: .now,
            featuredGame: FeaturedGame(
                id: UUID(),
                title: "Elden Ring",
                lastPlayedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now),
                latestNote: "Need to clear the catacombs before heading back to the capital.",
                nextTask: "Buy more arrows and upgrade the bow",
                pendingTasksCount: 2,
                coverImageData: nil
            ),
            recentGames: [
                FeaturedGame(
                    id: UUID(),
                    title: "Elden Ring",
                    lastPlayedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now),
                    latestNote: "Need to clear the catacombs before heading back to the capital.",
                    nextTask: "Buy more arrows and upgrade the bow",
                    pendingTasksCount: 2,
                    coverImageData: nil
                ),
                FeaturedGame(
                    id: UUID(),
                    title: "Red Dead Redemption 2",
                    lastPlayedAt: Calendar.current.date(byAdding: .day, value: -3, to: .now),
                    latestNote: "Continue chapter 3",
                    nextTask: "Hunt the legendary buck",
                    pendingTasksCount: 3,
                    coverImageData: nil
                ),
                FeaturedGame(
                    id: UUID(),
                    title: "Tears of the Kingdom",
                    lastPlayedAt: Calendar.current.date(byAdding: .day, value: -6, to: .now),
                    latestNote: "Return to the underground map",
                    nextTask: "Upgrade armor",
                    pendingTasksCount: 1,
                    coverImageData: nil
                ),
                FeaturedGame(
                    id: UUID(),
                    title: "Pokémon Silver",
                    lastPlayedAt: Calendar.current.date(byAdding: .day, value: -9, to: .now),
                    latestNote: "Need to train before the gym",
                    nextTask: "Catch electric type",
                    pendingTasksCount: 0,
                    coverImageData: nil
                )
            ]
        )
    }
}

struct CheckPointResumeWidget: Widget {
    let kind = "CheckPointResumeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CheckPointResumeProvider()) { entry in
            CheckPointResumeWidgetView(entry: entry)
        }
        .configurationDisplayName("Resume Session")
        .description("Jump back into the game you were last focused on.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct CheckPointResumeWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: CheckPointResumeEntry

    var body: some View {
        ZStack {
            backgroundLayer

            Group {
                switch family {
                case .systemLarge:
                    largeBody
                case .systemMedium:
                    mediumBody
                default:
                    smallBody
                }
            }
        }
        .widgetURL(widgetURL)
        .containerBackground(for: .widget) { Color.clear }
    }

    private var widgetURL: URL {
        guard let featuredGame = entry.snapshot.featuredGame else {
            return CheckpointDeepLink.libraryURL
        }

        return CheckpointDeepLink.gameURL(gameID: featuredGame.id)
    }

    private var smallBody: some View {
        Group {
            if let featuredGame = entry.snapshot.featuredGame {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(alignment: .center, spacing: 10) {
                        Text(CheckpointActivityFormatter.lastActivityLabel(for: featuredGame.lastPlayedAt))
                            .font(.title3.weight(.black))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .multilineTextAlignment(.center)
                            .shadow(color: .black.opacity(0.30), radius: 10, x: 0, y: 4)

                        statusPill(
                            title: featuredGame.pendingTasksCount == 1 ? "1 task pending" : "\(featuredGame.pendingTasksCount) tasks pending",
                            systemImage: "checklist"
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 10)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 18)
                .padding(.vertical, 18)
            } else {
                emptyState
            }
        }
    }

    private var mediumBody: some View {
        Group {
            if let featuredGame = entry.snapshot.featuredGame {
                ZStack {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top, spacing: 10) {
                            coverThumbnail(for: featuredGame, size: 56)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(featuredGame.title)
                                    .font(.title3.weight(.black))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)

                                Text(CheckpointActivityFormatter.lastActivityLabel(for: featuredGame.lastPlayedAt))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(widgetAccent.opacity(0.92))
                                    .lineLimit(1)

                                compactTasksBadge(pendingCount: featuredGame.pendingTasksCount)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 78, maxHeight: 78, alignment: .topLeading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(CheckpointResumeCopy.latestNotePrefix.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(widgetAccent.opacity(0.88))

                            Text(featuredGame.latestNote ?? CheckpointResumeCopy.latestNoteFallback)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46, alignment: .topLeading)
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 14)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, minHeight: 142, maxHeight: 142, alignment: .topLeading)
                    .background(contentPanelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(widgetAccent.opacity(0.34), lineWidth: 1.5)
                    }
                    .overlay(alignment: .topLeading) {
                        Capsule(style: .continuous)
                            .fill(widgetAccent)
                            .frame(width: 72, height: 5)
                            .padding(.top, 1)
                            .padding(.leading, 14)
                    }
                    .shadow(color: .black.opacity(0.26), radius: 18, x: 0, y: 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            } else {
                emptyState
            }
        }
    }

    private var largeBody: some View {
        Group {
            if entry.snapshot.recentGames.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("RECENTLY PLAYED")
                            .font(.caption.weight(.black))
                            .kerning(1)
                            .foregroundStyle(widgetAccent.opacity(0.95))

                        Spacer(minLength: 12)

                        Text("\(entry.snapshot.recentGames.count) games")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }

                    Text("Pick up where you left off")
                        .font(.title3.weight(.black))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                        .shadow(color: .black.opacity(0.24), radius: 8, x: 0, y: 4)

                    VStack(spacing: 10) {
                        ForEach(Array(entry.snapshot.recentGames.prefix(5).enumerated()), id: \.element.id) { index, game in
                            largeRow(for: game, isFirst: index == 0)
                        }
                    }
                    .padding(.top, 14)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(contentPanelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(widgetAccent.opacity(0.28), lineWidth: 1.5)
                }
                .overlay(alignment: .topLeading) {
                    Capsule(style: .continuous)
                        .fill(widgetAccent)
                        .frame(width: 88, height: 6)
                        .padding(.top, 2)
                        .padding(.leading, 18)
                }
                .shadow(color: .black.opacity(0.26), radius: 22, x: 0, y: 12)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
    }

    private func compactTasksBadge(pendingCount: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checklist")
                .font(.caption2.weight(.bold))

            Text("\(pendingCount)")
                .font(.caption.weight(.black))

            Text(pendingCount == 1 ? "task" : "tasks")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(widgetAccent.opacity(0.28))
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(widgetAccent.opacity(0.5), lineWidth: 1)
        }
    }

    private func smallMetricCapsule(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(widgetAccent.opacity(0.42), lineWidth: 1)
            }
    }

    private func largeRow(for game: FeaturedGame, isFirst: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            coverThumbnail(for: game, size: isFirst ? 46 : 38)

            VStack(alignment: .leading, spacing: isFirst ? 5 : 3) {
                Text(game.title)
                    .font((isFirst ? Font.headline : .subheadline).weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(CheckpointActivityFormatter.lastActivityLabel(for: game.lastPlayedAt))
                    .font(isFirst ? .caption.weight(.semibold) : .caption2.weight(.semibold))
                    .foregroundStyle(widgetAccent.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if game.pendingTasksCount > 0 {
                compactTasksBadge(pendingCount: game.pendingTasksCount)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.65))
            }
        }
        .padding(.horizontal, isFirst ? 12 : 10)
        .padding(.vertical, isFirst ? 10 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: isFirst ? 18 : 16, style: .continuous)
                .fill(Color.black.opacity(isFirst ? 0.26 : 0.18))
        )
        .overlay {
            RoundedRectangle(cornerRadius: isFirst ? 18 : 16, style: .continuous)
                .strokeBorder(widgetAccent.opacity(isFirst ? 0.24 : 0.16), lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "gamecontroller")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.white.opacity(0.82))

            Text(CheckpointResumeCopy.emptyWidgetTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(CheckpointResumeCopy.emptyWidgetMessage)
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.82))
                .lineLimit(family == .systemMedium ? 3 : 4)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if let featuredGame = entry.snapshot.featuredGame {
            backgroundArt(for: featuredGame)
        } else {
            fallbackBackground
        }
    }

    @ViewBuilder
    private func backgroundArt(for featuredGame: FeaturedGame) -> some View {
        if let coverImageData = featuredGame.coverImageData,
           let image = UIImage(data: coverImageData) {
            ZStack {
                fallbackBackground

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(1.03)
                    .clipped()

                Rectangle()
                    .fill(Color.black.opacity(family == .systemMedium ? 0.28 : 0.20))

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.06),
                        Color.black.opacity(family == .systemMedium ? 0.36 : 0.18),
                        Color.black.opacity(family == .systemMedium ? 0.72 : 0.52)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RadialGradient(
                    colors: [
                        Color.clear,
                        Color.black.opacity(0.18)
                    ],
                    center: .topTrailing,
                    startRadius: 12,
                    endRadius: family == .systemMedium ? 220 : 140
                )
            }
        } else {
            fallbackBackground
        }
    }

    private var fallbackBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.16, blue: 0.14),
                Color(red: 0.05, green: 0.08, blue: 0.11),
                Color(red: 0.02, green: 0.03, blue: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                widgetAccent.opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RadialGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.clear
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 180
                )
            }
        }
    }

    private var contentPanelBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.60),
                            Color.black.opacity(0.46)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(widgetAccent.opacity(0.04))
        }
    }

    private func statusPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(widgetAccent.opacity(0.28))
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(widgetAccent.opacity(0.5), lineWidth: 1)
            }
    }

    @ViewBuilder
    private func coverThumbnail(for featuredGame: FeaturedGame, size: CGFloat) -> some View {
        if let coverImageData = featuredGame.coverImageData,
           let image = UIImage(data: coverImageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(widgetAccent.opacity(0.72), lineWidth: 1.5)
                }
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
        }
    }

    private var widgetAccent: Color {
        Color(red: 0.42, green: 0.87, blue: 0.78)
    }
}
