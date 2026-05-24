import SwiftUI
import UIKit
import WidgetKit

private struct GamerPanelShape: InsettableShape {
    var cut: CGFloat = 16
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let c = min(cut, min(rect.width, rect.height) / 3)
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - c * 0.45, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + c * 0.55))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + c * 0.35, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - c * 0.8))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + c * 0.55))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

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
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        coverThumbnail(for: featuredGame, size: 42)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("NEXT LOAD")
                                .font(.caption2.weight(.black))
                                .fontWidth(.condensed)
                                .foregroundStyle(widgetAccent)
                                .lineLimit(1)

                            Text(featuredGame.title)
                                .font(.caption.weight(.black))
                                .fontWidth(.condensed)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                    }

                    Spacer(minLength: 0)

                    Text(CheckpointActivityFormatter.compactLastActivityLabel(for: featuredGame.lastPlayedAt))
                        .font(.title3.weight(.black))
                        .fontWidth(.condensed)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    statusPill(
                        title: featuredGame.pendingTasksCount == 1 ? "1 TASK" : "\(featuredGame.pendingTasksCount) TASKS",
                        systemImage: "scope"
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(
                    GamerPanelShape(cut: 22)
                        .fill(contentPanelGradient)
                )
                .overlay {
                    GamerPanelShape(cut: 22)
                        .strokeBorder(widgetAccent.opacity(0.55), lineWidth: 1.2)
                }
                .shadow(color: widgetAccent.opacity(0.24), radius: 14, x: 0, y: 6)
                .padding(10)
            } else {
                emptyState
            }
        }
    }

    private var mediumBody: some View {
        Group {
            if let featuredGame = entry.snapshot.featuredGame {
                HStack(alignment: .center, spacing: 12) {
                    coverThumbnail(for: featuredGame, size: 64)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            Text("RESUME")
                                .font(.caption2.weight(.black))
                                .fontWidth(.condensed)
                                .foregroundStyle(widgetAccent)
                            compactTasksBadge(pendingCount: featuredGame.pendingTasksCount)
                        }

                        Text(featuredGame.title)
                            .font(.title3.weight(.black))
                            .fontWidth(.condensed)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .shadow(color: .black.opacity(0.30), radius: 10, x: 0, y: 4)

                        Text(CheckpointActivityFormatter.lastActivityLabel(for: featuredGame.lastPlayedAt))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(widgetAccent.opacity(0.95))
                            .lineLimit(1)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("LAST SESSION")
                                .font(.caption2.weight(.black))
                                .fontWidth(.condensed)
                                .foregroundStyle(Color.white.opacity(0.62))

                            Text(featuredGame.latestNote ?? CheckpointResumeCopy.latestNoteFallback)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(GamerPanelShape(cut: 24).fill(contentPanelGradient))
                .overlay {
                    GamerPanelShape(cut: 24)
                        .strokeBorder(widgetAccent.opacity(0.48), lineWidth: 1.35)
                }
                .overlay(alignment: .topLeading) {
                    Capsule(style: .continuous)
                        .fill(widgetAccent)
                        .frame(width: 74, height: 5)
                        .padding(.top, 2)
                        .padding(.leading, 18)
                }
                .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
                .padding(.horizontal, 16)
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
                    }

                    VStack(spacing: 8) {
                        ForEach(Array(entry.snapshot.recentGames.prefix(4)), id: \.id) { game in
                            largeRow(for: game)
                        }
                    }
                    .padding(.top, 12)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(GamerPanelShape(cut: 28).fill(contentPanelGradient))
                .overlay {
                    GamerPanelShape(cut: 28)
                        .strokeBorder(widgetAccent.opacity(0.28), lineWidth: 1.5)
                }
                .overlay(alignment: .topLeading) {
                    Capsule(style: .continuous)
                        .fill(widgetAccent)
                        .frame(width: 88, height: 6)
                        .padding(.top, 2)
                        .padding(.leading, 24)
                }
                .shadow(color: .black.opacity(0.26), radius: 22, x: 0, y: 12)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
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

    private func largeRow(for game: FeaturedGame) -> some View {
        HStack(alignment: .center, spacing: 12) {
            coverThumbnail(for: game, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(CheckpointActivityFormatter.compactLastActivityLabel(for: game.lastPlayedAt))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(widgetAccent.opacity(0.9))
                    .lineLimit(1)
            }

            Spacer(minLength: 10)

            largeTrailingStatus(for: game)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 54, alignment: .leading)
        .background(
            GamerPanelShape(cut: 12)
                .fill(Color.black.opacity(0.20))
        )
        .overlay {
            GamerPanelShape(cut: 12)
                .strokeBorder(widgetAccent.opacity(0.16), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func largeTrailingStatus(for game: FeaturedGame) -> some View {
        if game.pendingTasksCount > 0 {
            Text(game.pendingTasksCount == 1 ? "1 task" : "\(game.pendingTasksCount) tasks")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .frame(width: 68, alignment: .trailing)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white.opacity(0.65))
                .frame(width: 68, alignment: .trailing)
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
        if family == .systemLarge {
            fallbackBackground
        } else if let featuredGame = entry.snapshot.featuredGame {
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
                        urgentAccent.opacity(0.24),
                        Color.clear
                    ],
                    center: .bottomTrailing,
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
                Color(red: 0.04, green: 0.07, blue: 0.11),
                Color(red: 0.02, green: 0.02, blue: 0.05)
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
                                Color.clear,
                                urgentAccent.opacity(0.16)
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
            GamerPanelShape(cut: 22)
                .fill(
                    contentPanelGradient
                )

            GamerPanelShape(cut: 22)
                .fill(widgetAccent.opacity(0.04))
        }
    }

    private var contentPanelGradient: LinearGradient {
        LinearGradient(
            colors: [
                widgetAccent.opacity(0.18),
                Color.black.opacity(0.64),
                urgentAccent.opacity(0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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
                .clipShape(GamerPanelShape(cut: size * 0.20))
                .overlay {
                    GamerPanelShape(cut: size * 0.20)
                        .strokeBorder(widgetAccent.opacity(0.72), lineWidth: 1.5)
                }
        } else {
            GamerPanelShape(cut: size * 0.20)
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
        Color(red: 0.08, green: 0.93, blue: 0.82)
    }

    private var urgentAccent: Color {
        Color(red: 1.00, green: 0.07, blue: 0.31)
    }
}
