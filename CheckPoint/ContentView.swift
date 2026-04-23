import SwiftUI
import SwiftData
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        LibraryView()
            .tint(QuietConsoleTheme.accent)
    }
}

private struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Query private var games: [Game]
    @State private var showingAddGame = false
    @State private var showingBackupImporter = false
    @State private var showingBackupExporter = false
    @State private var showingImportModeDialog = false
    @State private var backupDocument = CheckpointBackupDocument(data: Data())
    @State private var backupFilename = "checkpoint-backup"
    @State private var pendingImportedBackup: CheckpointBackup?
    @State private var backupAlertMessage: String?
    @State private var showingBackupAlert = false
    @State private var showingBackupCenter = false
    @State private var navigationPath: [UUID] = []
    @State private var pendingDeepLinkGameID: UUID?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if games.isEmpty {
                    ContentUnavailableView(
                        "No Games Yet",
                        systemImage: "gamecontroller",
                        description: Text("Add a game to keep momentum between sessions.")
                    )
                } else {
                    List {
                        ForEach(sortedGames) { game in
                            gameRow(for: game)
                        }
                        .onDelete(perform: deleteGames)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(QuietConsoleTheme.canvas)
                }
            }
            .navigationTitle("Checkpoint")
            .background(QuietConsoleTheme.canvas)
            .toolbar(content: toolbarContent)
            .sheet(isPresented: $showingAddGame) {
                AddEditGameView(mode: .add)
            }
            .sheet(isPresented: $showingBackupCenter) {
                backupCenterSheet
            }
            .fileExporter(
                isPresented: $showingBackupExporter,
                document: backupDocument,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                switch result {
                case .success:
                    showBackupAlert("Backup saved to Files.")
                case .failure:
                    showBackupAlert("Couldn't export backup.")
                }
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            }
            .confirmationDialog(
                "Import backup",
                isPresented: $showingImportModeDialog,
                titleVisibility: .visible
            ) {
                Button("Merge with library") {
                    importPendingBackup(mode: .merge)
                }
                Button("Replace library", role: .destructive) {
                    importPendingBackup(mode: .replace)
                }
                Button("Cancel", role: .cancel) {
                    pendingImportedBackup = nil
                }
            } message: {
                Text("Merge keeps your current data and adds updates from this backup. Replace clears your current library first.")
            }
            .alert("Backup", isPresented: $showingBackupAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupAlertMessage ?? "Done.")
            }
            .navigationDestination(for: UUID.self) { gameID in
                if let game = games.first(where: { $0.id == gameID }) {
                    GameDetailView(game: game)
                } else {
                    ContentUnavailableView(
                        "Game Not Found",
                        systemImage: "questionmark.circle",
                        description: Text("That game is no longer available in your library.")
                    )
                }
            }
            .onAppear {
                CheckpointWidgetSync.sync(games: games)
                routePendingDeepLinkIfPossible()
            }
            .onChange(of: games.map(\.id)) { _, _ in
                routePendingDeepLinkIfPossible()
            }
            .onOpenURL { url in
                pendingDeepLinkGameID = CheckpointDeepLink.gameID(from: url)
                routePendingDeepLinkIfPossible()
            }
        }
    }

    private var backupCenterSheet: some View {
        NavigationStack {
            Form {
                Section("Backup & Restore") {
                    Text("Checkpoint stores data on this device. To move to a new phone, export a backup to iCloud Drive, then import it on the new device.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Before You Switch Phones") {
                    Text("1. Tap Export Backup")
                    Text("2. Save it in iCloud Drive")
                    Text("3. On the new phone, tap Import Backup")
                }

                Section("Actions") {
                    Button {
                        showingBackupCenter = false
                        prepareBackupExport()
                    } label: {
                        Label("Export Backup", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingBackupCenter = false
                        showingBackupImporter = true
                    } label: {
                        Label("Import Backup", systemImage: "square.and.arrow.down")
                    }
                }

                Section("Import Behavior") {
                    Text("Merge: keeps current data and applies backup updates.")
                    Text("Replace: clears current data and restores only this backup.")
                }
            }
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingBackupCenter = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func gameRow(for game: Game) -> some View {
        NavigationLink(value: game.id) {
            GameCardView(game: game)
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            EditButton()
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingAddGame = true
            } label: {
                Label("Add Game", systemImage: "plus")
            }
            .accessibilityHint("Adds a game to your library")
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Section("Help Improve CheckPoint") {
                    Button {
                        sendFeedback(kind: .general)
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }

                    Button {
                        sendFeedback(kind: .feature)
                    } label: {
                        Label("Request a Feature", systemImage: "lightbulb")
                    }
                }

                Section("Backup") {
                Button {
                    showingBackupCenter = true
                } label: {
                    Label("Backup & Restore", systemImage: "externaldrive.badge.icloud")
                }

                Button {
                    prepareBackupExport()
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }

                Button {
                    showingBackupImporter = true
                } label: {
                    Label("Import Backup", systemImage: "square.and.arrow.down")
                }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.semibold))
            }
            .accessibilityLabel("App options")
        }
    }

    private func sendFeedback(kind: FeedbackKind) {
        guard let url = kind.mailURL else { return }
        openURL(url)
    }

    private func deleteGames(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedGames[index])
        }

        saveLibraryChanges()
    }

    private var sortedGames: [Game] {
        games.sorted { lhs, rhs in
            switch (lhs.lastPlayedAt, rhs.lastPlayedAt) {
            case let (left?, right?):
                if left != right { return left > right }
                return lhs.createdAt > rhs.createdAt
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.createdAt > rhs.createdAt
            }
        }
    }

    private func prepareBackupExport() {
        do {
            let backup = CheckpointBackup.from(games: games)
            backupDocument = CheckpointBackupDocument(data: try backup.jsonData())
            backupFilename = "checkpoint-backup-\(Date.backupFileStamp)"
            showingBackupExporter = true
        } catch {
            showBackupAlert("Couldn't create backup data.")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            showBackupAlert("Couldn't open backup file.")
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let isSecurityScoped = url.startAccessingSecurityScopedResource()
                defer {
                    if isSecurityScoped {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let data = try Data(contentsOf: url)
                let backup = try CheckpointBackup.decode(from: data)
                guard backup.schemaVersion == CheckpointBackup.currentSchemaVersion else {
                    showBackupAlert("This backup version isn't supported yet.")
                    return
                }
                pendingImportedBackup = backup
                showingImportModeDialog = true
            } catch {
                showBackupAlert("Backup file is invalid or unreadable.")
            }
        }
    }

    private func importPendingBackup(mode: BackupImportMode) {
        guard let backup = pendingImportedBackup else { return }

        switch mode {
        case .replace:
            for game in games {
                modelContext.delete(game)
            }
        case .merge:
            break
        }

        var existingByID = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
        if mode == .replace {
            existingByID = [:]
        }

        for snapshot in backup.games {
            if let existing = existingByID[snapshot.id] {
                apply(snapshot: snapshot, to: existing)
            } else {
                let game = makeGame(from: snapshot)
                modelContext.insert(game)
                existingByID[snapshot.id] = game
            }
        }

        do {
            try modelContext.save()
            CheckpointWidgetSync.sync(using: modelContext)
            switch mode {
            case .merge:
                showBackupAlert("Backup imported with merge.")
            case .replace:
                showBackupAlert("Backup imported and library replaced.")
            }
        } catch {
            showBackupAlert("Couldn't save imported backup.")
        }

        pendingImportedBackup = nil
    }

    private func makeGame(from snapshot: CheckpointBackup.GameSnapshot) -> Game {
        let game = Game(
            id: snapshot.id,
            title: snapshot.title,
            createdAt: snapshot.createdAt,
            lastPlayedAt: snapshot.lastPlayedAt,
            coverImageData: snapshot.coverImageData
        )

        for noteSnapshot in snapshot.notes {
            let note = GameNote(
                id: noteSnapshot.id,
                createdAt: noteSnapshot.createdAt,
                text: noteSnapshot.text,
                photoData: noteSnapshot.photoData,
                game: game
            )
            modelContext.insert(note)
            game.notes.append(note)
        }

        for taskSnapshot in snapshot.tasks {
            let task = GameTask(
                id: taskSnapshot.id,
                createdAt: taskSnapshot.createdAt,
                text: taskSnapshot.text,
                isDone: taskSnapshot.isDone,
                game: game
            )
            modelContext.insert(task)
            game.tasks.append(task)
        }

        for resourceSnapshot in snapshot.resources {
            let resource = GameResource(
                id: resourceSnapshot.id,
                createdAt: resourceSnapshot.createdAt,
                title: resourceSnapshot.title,
                urlString: resourceSnapshot.urlString,
                lastUsedAt: resourceSnapshot.lastUsedAt,
                game: game
            )
            modelContext.insert(resource)
            game.resources.append(resource)
        }

        return game
    }

    private func apply(snapshot: CheckpointBackup.GameSnapshot, to game: Game) {
        game.title = snapshot.title
        game.createdAt = snapshot.createdAt
        game.lastPlayedAt = snapshot.lastPlayedAt
        game.coverImageData = snapshot.coverImageData

        var notesByID = Dictionary(uniqueKeysWithValues: game.notes.map { ($0.id, $0) })
        for noteSnapshot in snapshot.notes {
            if let note = notesByID[noteSnapshot.id] {
                note.createdAt = noteSnapshot.createdAt
                note.text = noteSnapshot.text
                note.photoData = noteSnapshot.photoData
            } else {
                let note = GameNote(
                    id: noteSnapshot.id,
                    createdAt: noteSnapshot.createdAt,
                    text: noteSnapshot.text,
                    photoData: noteSnapshot.photoData,
                    game: game
                )
                modelContext.insert(note)
                game.notes.append(note)
                notesByID[note.id] = note
            }
        }

        var tasksByID = Dictionary(uniqueKeysWithValues: game.tasks.map { ($0.id, $0) })
        for taskSnapshot in snapshot.tasks {
            if let task = tasksByID[taskSnapshot.id] {
                task.createdAt = taskSnapshot.createdAt
                task.text = taskSnapshot.text
                task.isDone = taskSnapshot.isDone
            } else {
                let task = GameTask(
                    id: taskSnapshot.id,
                    createdAt: taskSnapshot.createdAt,
                    text: taskSnapshot.text,
                    isDone: taskSnapshot.isDone,
                    game: game
                )
                modelContext.insert(task)
                game.tasks.append(task)
                tasksByID[task.id] = task
            }
        }

        var resourcesByID = Dictionary(uniqueKeysWithValues: game.resources.map { ($0.id, $0) })
        for resourceSnapshot in snapshot.resources {
            if let resource = resourcesByID[resourceSnapshot.id] {
                resource.createdAt = resourceSnapshot.createdAt
                resource.title = resourceSnapshot.title
                resource.urlString = resourceSnapshot.urlString
                resource.lastUsedAt = resourceSnapshot.lastUsedAt
            } else {
                let resource = GameResource(
                    id: resourceSnapshot.id,
                    createdAt: resourceSnapshot.createdAt,
                    title: resourceSnapshot.title,
                    urlString: resourceSnapshot.urlString,
                    lastUsedAt: resourceSnapshot.lastUsedAt,
                    game: game
                )
                modelContext.insert(resource)
                game.resources.append(resource)
                resourcesByID[resource.id] = resource
            }
        }
    }

    private func showBackupAlert(_ message: String) {
        backupAlertMessage = message
        showingBackupAlert = true
    }

    private func saveLibraryChanges() {
        do {
            try modelContext.save()
            CheckpointWidgetSync.sync(using: modelContext)
        } catch {
            assertionFailure("Failed saving library changes: \(error)")
        }
    }

    private func routePendingDeepLinkIfPossible() {
        guard let pendingDeepLinkGameID,
              games.contains(where: { $0.id == pendingDeepLinkGameID }) else {
            return
        }

        navigationPath = [pendingDeepLinkGameID]
        self.pendingDeepLinkGameID = nil
    }
}

private enum FeedbackKind {
    case general
    case feature

    private static let emailAddress = "checkpoint.support@gmail.com"

    var subject: String {
        switch self {
        case .general:
            return "CheckPoint Feedback"
        case .feature:
            return "CheckPoint Feature Request"
        }
    }

    var body: String {
        switch self {
        case .general:
            return """
            Hi,

            I'd like to share some feedback about CheckPoint:



            App version:
            iOS version:
            Device:
            """
        case .feature:
            return """
            Hi,

            I'd love to see this in CheckPoint:



            Why it would help:


            App version:
            iOS version:
            Device:
            """
        }
    }

    var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.emailAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

private struct GameCardView: View {
    let game: Game

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            coverImage

            VStack(alignment: .leading, spacing: 8) {
                Text(game.title)
                    .font(.title3.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(GameActivityFormatter.lastActivityLabel(for: game.lastPlayedAt))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuietConsoleTheme.activityText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(QuietConsoleTheme.activityFill)
                    )

                if let latestNoteText {
                    Text(latestNoteText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(16)
        .quietSurface(.primary, cornerRadius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var coverImage: some View {
        if let data = game.coverImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(QuietConsoleTheme.cardBorder, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(QuietConsoleTheme.secondaryFill)
                .frame(width: 68, height: 68)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(QuietConsoleTheme.subtleText)
                }
        }
    }

    private var latestNoteText: String? {
        guard let latestNote = game.notes.sorted(by: { $0.createdAt > $1.createdAt }).first else {
            return nil
        }

        let trimmed = latestNote.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return latestNote.photoData == nil ? nil : "Photo checkpoint"
        }
        return trimmed
    }
}

private struct GameDetailView: View {
    private enum ActiveSheet: String, Identifiable {
        case edit
        case quickNote
        case quickTask
        case resume
        var id: String { rawValue }
    }

    private enum ResourceEditor: Identifiable {
        case add
        case edit(GameResource)

        var id: String {
            switch self {
            case .add:
                return "add-resource"
            case .edit(let resource):
                return "edit-resource-\(resource.id.uuidString)"
            }
        }

        var resource: GameResource? {
            switch self {
            case .add:
                return nil
            case .edit(let resource):
                return resource
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.openURL) private var openURL
    @Bindable var game: Game

    @State private var activeSheet: ActiveSheet?
    @State private var showingDeleteConfirmation = false
    @State private var quickNoteText = ""
    @State private var quickNotePhotoItem: PhotosPickerItem?
    @State private var quickNoteImageData: Data?
    @State private var quickTaskText = ""
    @State private var savedMessage: String?
    @State private var savedMessageTask: Task<Void, Never>?
    @State private var editingNote: GameNote?
    @State private var editingNoteText = ""
    @State private var editingNotePhotoItem: PhotosPickerItem?
    @State private var editingNoteImageData: Data?
    @State private var previewImageData: Data?
    @State private var resumePreviewImageData: Data?
    @State private var notePendingDeletion: GameNote?
    @State private var activeResourceEditor: ResourceEditor?
    @State private var resourcePendingDeletion: GameResource?
    @State private var resourceDraftTitle = ""
    @State private var resourceDraftURL = ""
    @FocusState private var isQuickNoteFieldFocused: Bool
    @FocusState private var isQuickTaskFieldFocused: Bool
    @FocusState private var isResourceURLFieldFocused: Bool
    @FocusState private var isEditNoteFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                notesSection
                resourcesSection
                tasksSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(QuietConsoleTheme.canvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                quickResumeCard
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            .background(QuietConsoleTheme.canvas)
        }
        .navigationTitle(game.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit") {
                        activeSheet = .edit
                    }
                    Button("Delete Game", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .alert("Delete this game?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteGame()
            }
        } message: {
            Text("This will remove the game, notes, and tasks from this device.")
        }
        .alert("Delete this note?", isPresented: isShowingDeleteNoteConfirmation) {
            Button("Cancel", role: .cancel) {
                notePendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                deletePendingNote()
            }
        } message: {
            Text("This note will be removed from this game.")
        }
        .alert("Delete this link?", isPresented: isShowingDeleteResourceConfirmation) {
            Button("Cancel", role: .cancel) {
                resourcePendingDeletion = nil
            }
            Button("Delete", role: .destructive) {
                deletePendingResource()
            }
        } message: {
            Text("This link will be removed from this game.")
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .edit:
                AddEditGameView(mode: .edit(game))
            case .quickNote:
                quickNoteComposer
            case .quickTask:
                quickTaskComposer
            case .resume:
                resumeSessionSheet
            }
        }
        .sheet(item: $editingNote) { _ in
            editNoteComposer
        }
        .sheet(item: $activeResourceEditor) { _ in
            resourceComposer
        }
        .sheet(isPresented: isShowingImagePreview) {
            noteImagePreviewSheet(
                imageData: previewImageData,
                dismissAction: { previewImageData = nil }
            )
        }
    }

    private var quickResumeCard: some View {
        VStack(alignment: .leading, spacing: compactQuickResumeLayout ? 8 : 12) {
            HStack {
                Text("Session Checkpoint")
                    .font(compactQuickResumeLayout ? .headline.weight(.bold) : .title3.weight(.bold))
                    .fontDesign(.rounded)

                Spacer()

                Button { activeSheet = .quickTask } label: { Text("+ Task") }
                    .buttonStyle(.borderedProminent)
                    .tint(QuietConsoleTheme.accent)
                    .controlSize(compactQuickResumeLayout ? .small : .regular)

                Button { activeSheet = .quickNote } label: { Text("+ Note") }
                    .buttonStyle(.borderedProminent)
                    .tint(QuietConsoleTheme.accent)
                    .controlSize(compactQuickResumeLayout ? .small : .regular)

                Button { beginAddingResource() } label: { Text("+ Link") }
                    .buttonStyle(.borderedProminent)
                    .tint(QuietConsoleTheme.accent)
                    .controlSize(compactQuickResumeLayout ? .small : .regular)
            }

            Button {
                markGameResumed()
                activeSheet = .resume
            } label: {
                Label(compactQuickResumeLayout ? "Resume" : "Resume Session", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(QuietConsoleTheme.accent)
            .controlSize(compactQuickResumeLayout ? .small : .regular)

            Text("\(QuickResumeCopy.latestNotePrefix):")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(latestNoteText)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(pendingTasksSummary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(GameActivityFormatter.lastActivityLabel(for: game.lastPlayedAt))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if sortedResources.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Resources:")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(sortedResources.prefix(2)) { resource in
                        Button {
                            open(resource)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "link")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(QuietConsoleTheme.accent)
                                Text(resource.displayTitle)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let savedMessage {
                Text(savedMessage)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(QuietConsoleTheme.accent)
                    .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    .accessibilityLabel(savedMessage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .quietSurface(.elevated, cornerRadius: 20)
    }

    private var resumeSessionSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 14) {
                        resumeCoverImage

                        VStack(alignment: .leading, spacing: 8) {
                            Text(game.title)
                                .font(.title2.weight(.bold))
                                .fontDesign(.rounded)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(GameActivityFormatter.lastActivityLabel(for: game.lastPlayedAt))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(QuietConsoleTheme.activityText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(QuietConsoleTheme.activityFill)
                                )

                            Text(pendingTasksSummary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Latest note")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(latestNoteText)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let latestNotePreviewImage {
                            Button {
                                resumePreviewImageData = latestNote?.photoData
                            } label: {
                                Image(uiImage: latestNotePreviewImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 156)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open latest note photo")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .quietSurface(.secondary, cornerRadius: 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Up next")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        if sortedTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("You're clear")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Jump in now, or drop a quick note first.")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                            }
                        } else {
                            VStack(spacing: 10) {
                                ForEach(sortedTasks.prefix(4)) { task in
                                    Button {
                                        toggleTask(task)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(task.isDone ? .green : QuietConsoleTheme.accent)
                                            Text(task.text)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(task.isDone ? .secondary : .primary)
                                                .strikethrough(task.isDone)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 12)
                                        .contentShape(Rectangle())
                                        .quietSurface(.primary, cornerRadius: 12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .quietSurface(.secondary, cornerRadius: 16)

                    if sortedResources.isEmpty == false {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Resources")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

                            VStack(spacing: 10) {
                                ForEach(sortedResources.prefix(4)) { resource in
                                    Button {
                                        open(resource)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "link")
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(QuietConsoleTheme.accent)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(resource.displayTitle)
                                                    .font(.body.weight(.medium))
                                                    .foregroundStyle(.primary)
                                                    .lineLimit(1)

                                                Text(resource.urlString)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }

                                            Spacer(minLength: 8)

                                            Image(systemName: "arrow.up.right")
                                                .font(.footnote.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 12)
                                        .quietSurface(.primary, cornerRadius: 12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .quietSurface(.secondary, cornerRadius: 16)
                    }
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        activeSheet = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: isShowingResumeImagePreview) {
            noteImagePreviewSheet(
                imageData: resumePreviewImageData,
                dismissAction: { resumePreviewImageData = nil }
            )
        }
    }

    @ViewBuilder
    private var resumeCoverImage: some View {
        if let data = game.coverImageData,
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(QuietConsoleTheme.cardBorder, lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(QuietConsoleTheme.secondaryFill)
                .frame(width: 96, height: 96)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 28, weight: .regular))
                        .foregroundStyle(QuietConsoleTheme.subtleText)
                }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline.weight(.semibold))
                .foregroundStyle(QuietConsoleTheme.subtleText)

            if sortedNotes.isEmpty {
                Text("No notes yet. Add a quick checkpoint.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(sortedNotes) { note in
                        noteRow(note)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: notesListHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .quietSurface(.primary, cornerRadius: 16)
    }

    private func noteRow(_ note: GameNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let displayText = noteDisplayText(for: note) {
                        Text(displayText)
                            .font(.body)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let image = notePreviewImage(from: note.photoData) {
                        Button {
                            previewImageData = note.photoData
                        } label: {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 148)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open note photo")
                    }

                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Menu {
                    Button("Edit Note") {
                        beginEditing(note)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(QuietConsoleTheme.subtleText)
                        .padding(.top, 2)
                }
                .accessibilityLabel("Note actions")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QuietConsoleTheme.secondaryFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                notePendingDeletion = note
            }
            .tint(.red)
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Tasks")
                .font(.headline.weight(.semibold))
                .foregroundStyle(QuietConsoleTheme.subtleText)

            if sortedTasks.isEmpty {
                Text("No tasks yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(sortedTasks) { task in
                        Button {
                            toggleTask(task)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? .green : .secondary)
                                Text(task.text)
                                    .font(.body)
                                    .foregroundStyle(task.isDone ? .secondary : .primary)
                                    .strikethrough(task.isDone)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Delete", role: .destructive) {
                                deleteTask(task)
                            }
                            .tint(.red)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: tasksListHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .quietSurface(.primary, cornerRadius: 16)
    }

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Resources")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(QuietConsoleTheme.subtleText)

                Spacer()

                Button {
                    beginAddingResource()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(QuietConsoleTheme.accent)
            }

            if sortedResources.isEmpty {
                Text("No links yet. Save a guide or video for later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedResources) { resource in
                        resourceRow(resource)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .quietSurface(.primary, cornerRadius: 16)
    }

    private func resourceRow(_ resource: GameResource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(resource.displayTitle)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(resource.urlString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(resource.kindLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(resource.kindTint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(resource.kindTint.opacity(0.14))
                    )
            }

            Text(resource.lastUsedLabel)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 8) {
                Button {
                    open(resource)
                } label: {
                    Label("Open", systemImage: "arrow.up.right")
                }
                .tint(QuietConsoleTheme.accent)

                Button {
                    beginEditing(resource)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                .tint(QuietConsoleTheme.accent)

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    resourcePendingDeletion = resource
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(QuietConsoleTheme.secondaryFill)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var quickNoteComposer: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("What should future you remember?", text: $quickNoteText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($isQuickNoteFieldFocused)
                    .onSubmit { quickSaveNote() }

                PhotosPicker(selection: $quickNotePhotoItem, matching: .images) {
                    Label(quickNoteImageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }

                if let previewImage = notePreviewImage(from: quickNoteImageData) {
                    noteComposerImagePreview(
                        image: previewImage,
                        removeAction: { quickNoteImageData = nil }
                    )
                }

                Button("Save Checkpoint") { quickSaveNote() }
                    .buttonStyle(.borderedProminent)
                    .tint(QuietConsoleTheme.accent)
                    .disabled(canSaveQuickNote == false)
            }
            .padding(16)
            .navigationTitle("Quick Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearQuickNoteDraft()
                        activeSheet = nil
                    }
                }
            }
            .onChange(of: quickNotePhotoItem) { _, newItem in
                Task {
                    let loadedData = try? await newItem?.loadTransferable(type: Data.self)
                    let optimizedData = optimizedNoteImageData(from: loadedData)
                    await MainActor.run {
                        quickNoteImageData = optimizedData
                    }
                }
            }
            .onAppear { isQuickNoteFieldFocused = true }
        }
        .presentationDetents([.medium])
    }

    private var quickTaskComposer: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Add immediate task", text: $quickTaskText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($isQuickTaskFieldFocused)
                    .onSubmit { quickSaveTask() }

                Button("Save Focus Task") { quickSaveTask() }
                    .buttonStyle(.borderedProminent)
                    .tint(QuietConsoleTheme.accent)
                    .disabled(quickTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .navigationTitle("Quick Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        quickTaskText = ""
                        activeSheet = nil
                    }
                }
            }
            .onAppear { isQuickTaskFieldFocused = true }
        }
        .presentationDetents([.height(190)])
    }

    private var editNoteComposer: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextEditor(text: $editingNoteText)
                    .frame(minHeight: 160)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(QuietConsoleTheme.secondaryFill)
                    )
                    .focused($isEditNoteFieldFocused)

                PhotosPicker(selection: $editingNotePhotoItem, matching: .images) {
                    Label(editingNoteImageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                }

                if let previewImage = notePreviewImage(from: editingNoteImageData) {
                    noteComposerImagePreview(
                        image: previewImage,
                        removeAction: { editingNoteImageData = nil }
                    )
                }

                Button("Save Changes") {
                    saveEditedNote()
                }
                .buttonStyle(.borderedProminent)
                .tint(QuietConsoleTheme.accent)
                .disabled(canSaveEditedNote == false)
            }
            .padding(16)
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingNote = nil
                    }
                }
            }
            .onChange(of: editingNotePhotoItem) { _, newItem in
                Task {
                    let loadedData = try? await newItem?.loadTransferable(type: Data.self)
                    let optimizedData = optimizedNoteImageData(from: loadedData)
                    await MainActor.run {
                        editingNoteImageData = optimizedData
                    }
                }
            }
            .onAppear { isEditNoteFieldFocused = true }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func noteComposerImagePreview(image: UIImage, removeAction: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button("Remove", role: .destructive) {
                removeAction()
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(.black.opacity(0.72))
            .padding(10)
        }
    }

    private func noteImagePreviewSheet(imageData: Data?, dismissAction: @escaping () -> Void) -> some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let previewImage = notePreviewImage(from: imageData) {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismissAction()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var resourceComposer: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Optional title", text: $resourceDraftTitle)
                    .textFieldStyle(.roundedBorder)

                TextField("https://...", text: $resourceDraftURL)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .focused($isResourceURLFieldFocused)
                    .onSubmit { saveResourceDraft() }

                Button(resourceBeingEdited == nil ? "Save Link" : "Save Changes") {
                    saveResourceDraft()
                }
                .buttonStyle(.borderedProminent)
                .tint(QuietConsoleTheme.accent)
                .disabled(normalizedResourceURL(resourceDraftURL) == nil)
            }
            .padding(16)
            .navigationTitle(resourceBeingEdited == nil ? "Quick Link" : "Edit Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearResourceDraft()
                        activeResourceEditor = nil
                    }
                }
            }
            .onAppear { isResourceURLFieldFocused = true }
        }
        .presentationDetents([.height(230)])
    }

    private var sortedNotes: [GameNote] {
        game.notes.sorted { $0.createdAt > $1.createdAt }
    }

    private var latestNote: GameNote? {
        sortedNotes.first
    }

    private var latestNotePreviewImage: UIImage? {
        notePreviewImage(from: latestNote?.photoData)
    }

    private var notesListHeight: CGFloat {
        sortedNotes.reduce(0) { partial, note in
            partial + noteRowHeight(for: note)
        }
    }

    private var sortedResources: [GameResource] {
        game.resources.sorted { lhs, rhs in
            if let l = lhs.lastUsedAt, let r = rhs.lastUsedAt, l != r {
                return l > r
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private var resourceBeingEdited: GameResource? {
        activeResourceEditor?.resource
    }

    private var sortedTasks: [GameTask] {
        game.tasks.sorted { lhs, rhs in
            if lhs.isDone != rhs.isDone { return lhs.isDone == false }
            return lhs.createdAt < rhs.createdAt
        }
    }

    private var tasksListHeight: CGFloat {
        let rowHeight: CGFloat = 56
        return CGFloat(sortedTasks.count) * rowHeight
    }

    private var pendingTasks: [GameTask] {
        sortedTasks.filter { $0.isDone == false }
    }

    private var latestNoteText: String {
        guard let latestNote = sortedNotes.first else {
            return QuickResumeCopy.latestNoteFallback
        }

        let trimmed = latestNote.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return latestNote.photoData == nil ? QuickResumeCopy.latestNoteFallback : "Photo checkpoint"
        }
        return trimmed
    }

    private var pendingTasksSummary: String {
        QuickResumeCopy.pendingTasksSummary(pendingCount: game.tasks.filter { !$0.isDone }.count)
    }

    private func noteRowHeight(for note: GameNote) -> CGFloat {
        let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let characterCount = max(trimmed.count, note.photoData == nil ? 0 : 16)
        let estimatedLines = min(4, max(1, Int(ceil(Double(characterCount) / 34.0))))
        let textHeight = CGFloat(estimatedLines) * 24
        let imageHeight: CGFloat = note.photoData == nil ? 0 : 156
        let spacing: CGFloat = note.photoData == nil ? 0 : 8
        let timestampHeight: CGFloat = 18
        let verticalPadding: CGFloat = 24
        let bottomSpacing: CGFloat = 8
        return textHeight + imageHeight + spacing + timestampHeight + verticalPadding + bottomSpacing
    }

    private var canSaveQuickNote: Bool {
        quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || quickNoteImageData != nil
    }

    private var canSaveEditedNote: Bool {
        editingNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || editingNoteImageData != nil
    }

    private var isShowingImagePreview: Binding<Bool> {
        Binding(
            get: { previewImageData != nil },
            set: { isPresented in
                if isPresented == false {
                    previewImageData = nil
                }
            }
        )
    }

    private var isShowingResumeImagePreview: Binding<Bool> {
        Binding(
            get: { resumePreviewImageData != nil },
            set: { isPresented in
                if isPresented == false {
                    resumePreviewImageData = nil
                }
            }
        )
    }

    private func quickSaveNote() {
        let trimmed = quickNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false || quickNoteImageData != nil else { return }

        let note = GameNote(text: trimmed, photoData: quickNoteImageData, game: game)
        modelContext.insert(note)
        game.notes.insert(note, at: 0)
        clearQuickNoteDraft()
        Haptics.success()
        saveContext()
        showSavedMessage("Checkpoint saved")
        activeSheet = nil
    }

    private func quickSaveTask() {
        let trimmed = quickTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task = GameTask(text: trimmed, isDone: false, game: game)
        modelContext.insert(task)
        game.tasks.append(task)
        quickTaskText = ""
        Haptics.success()
        saveContext()
        showSavedMessage("Task saved")
        activeSheet = nil
    }

    private var isShowingDeleteResourceConfirmation: Binding<Bool> {
        Binding(
            get: { resourcePendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    resourcePendingDeletion = nil
                }
            }
        )
    }

    private var isShowingDeleteNoteConfirmation: Binding<Bool> {
        Binding(
            get: { notePendingDeletion != nil },
            set: { isPresented in
                if isPresented == false {
                    notePendingDeletion = nil
                }
            }
        )
    }

    private func beginEditing(_ note: GameNote) {
        editingNoteText = note.text
        editingNoteImageData = note.photoData
        editingNotePhotoItem = nil
        editingNote = note
    }

    private func beginAddingResource() {
        resourceDraftTitle = ""
        resourceDraftURL = ""
        activeResourceEditor = .add
    }

    private func beginEditing(_ resource: GameResource) {
        resourceDraftTitle = resource.title
        resourceDraftURL = resource.urlString
        activeResourceEditor = .edit(resource)
    }

    private func saveEditedNote() {
        let trimmed = editingNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.isEmpty == false || editingNoteImageData != nil), let editingNote else { return }
        editingNote.text = trimmed
        editingNote.photoData = editingNoteImageData
        saveContext()
        showSavedMessage("Checkpoint updated")
        editingNotePhotoItem = nil
        editingNoteImageData = nil
        self.editingNote = nil
    }

    private func deletePendingNote() {
        guard let note = notePendingDeletion else { return }
        game.notes.removeAll { $0.id == note.id }
        modelContext.delete(note)
        notePendingDeletion = nil
        saveContext()
        showSavedMessage("Checkpoint deleted")
    }

    private func deleteTask(_ task: GameTask) {
        game.tasks.removeAll { $0.id == task.id }
        modelContext.delete(task)
        saveContext()
        showSavedMessage("Task deleted")
    }

    private func clearQuickNoteDraft() {
        quickNoteText = ""
        quickNotePhotoItem = nil
        quickNoteImageData = nil
    }

    private func toggleTask(_ task: GameTask) {
        withAnimation(.snappy(duration: 0.2)) {
            task.isDone.toggle()
        }
        Haptics.tap()
        saveContext()
    }

    private func saveResourceDraft() {
        guard let normalized = normalizedResourceURL(resourceDraftURL) else { return }
        let trimmedTitle = resourceDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        if let resourceBeingEdited {
            resourceBeingEdited.title = trimmedTitle
            resourceBeingEdited.urlString = normalized.absoluteString
            showSavedMessage("Link updated")
        } else {
            let resource = GameResource(
                title: trimmedTitle,
                urlString: normalized.absoluteString,
                game: game
            )
            modelContext.insert(resource)
            game.resources.append(resource)
            showSavedMessage("Link saved")
        }

        clearResourceDraft()
        activeResourceEditor = nil
        saveContext()
    }

    private func clearResourceDraft() {
        resourceDraftTitle = ""
        resourceDraftURL = ""
    }

    private func deletePendingResource() {
        guard let resource = resourcePendingDeletion else { return }
        game.resources.removeAll { $0.id == resource.id }
        modelContext.delete(resource)
        resourcePendingDeletion = nil
        saveContext()
        showSavedMessage("Link deleted")
    }

    private func normalizedResourceURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host?.isEmpty == false else { return nil }
        return url
    }

    private func open(_ resource: GameResource) {
        guard let url = normalizedResourceURL(resource.urlString) else {
            showSavedMessage("Invalid link")
            return
        }
        resource.lastUsedAt = .now
        saveContext()
        openURL(url)
    }

    private func markGameResumed(now: Date = .now) {
        game.lastPlayedAt = GameLastPlayedPolicy.updatedValue(
            for: game.lastPlayedAt,
            action: .resume,
            now: now
        )
        saveContext()
    }

    private func saveContext() {
        do {
            try modelContext.save()
            CheckpointWidgetSync.sync(using: modelContext)
        } catch {
            assertionFailure("Failed saving changes: \(error)")
        }
    }

    private func noteDisplayText(for note: GameNote) -> String? {
        let trimmed = note.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return note.photoData == nil ? nil : "Photo checkpoint"
        }
        return trimmed
    }

    private func notePreviewImage(from data: Data?) -> UIImage? {
        guard let data else { return nil }
        return UIImage(data: data)
    }

    private func optimizedNoteImageData(from originalData: Data?) -> Data? {
        guard let originalData,
              let image = UIImage(data: originalData) else {
            return nil
        }

        let maxDimension: CGFloat = 1800
        let maxArea: CGFloat = 3_200_000
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

        return resizedImage.jpegData(compressionQuality: 0.8)
    }

    private func deleteGame() {
        modelContext.delete(game)
        do {
            try modelContext.save()
            CheckpointWidgetSync.sync(using: modelContext)
            dismiss()
        } catch {
            assertionFailure("Failed deleting game: \(error)")
        }
    }

    private func showSavedMessage(_ message: String) {
        savedMessageTask?.cancel()
        withAnimation(.easeInOut(duration: 0.15)) {
            savedMessage = message
        }

        savedMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                savedMessage = nil
            }
        }
    }

    private var compactQuickResumeLayout: Bool {
        horizontalSizeClass == .compact && !dynamicTypeSize.isAccessibilitySize
    }
}

private struct AddEditGameView: View {
    enum Mode {
        case add
        case edit(Game)

        var title: String {
            switch self {
            case .add: return "Add Game"
            case .edit: return "Edit Game"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode

    @State private var title = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var coverImageData: Data?
    @State private var hasLoadedInitialValues = false
    @State private var rawgSuggestions: [RawgGameSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var selectedSuggestionID: Int?
    @State private var rawgStatusMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Game") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)

                    if isLoadingSuggestions {
                        ProgressView("Searching RAWG...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let rawgStatusMessage {
                        Text(rawgStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if rawgSuggestions.isEmpty == false {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggestions")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(rawgSuggestions) { suggestion in
                                Button {
                                    applySuggestion(suggestion)
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(suggestion.name)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        if selectedSuggestionID == suggestion.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Use suggestion \(suggestion.name)")
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(coverImageData == nil ? "Choose Cover" : "Change Cover", systemImage: "photo")
                    }

                    if let coverImageData,
                       let image = UIImage(data: coverImageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { loadInitialValuesIfNeeded() }
            .task(id: title) {
                await fetchSuggestionsIfNeeded(for: title)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    let loadedData = try? await newItem?.loadTransferable(type: Data.self)
                    await MainActor.run {
                        coverImageData = loadedData
                    }
                }
            }
        }
    }

    private func loadInitialValuesIfNeeded() {
        guard hasLoadedInitialValues == false else { return }
        hasLoadedInitialValues = true
        guard case .edit(let game) = mode else { return }
        title = game.title
        coverImageData = game.coverImageData
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        switch mode {
        case .add:
            modelContext.insert(Game(title: cleanTitle, createdAt: .now, coverImageData: coverImageData))
        case .edit(let game):
            game.title = cleanTitle
            game.coverImageData = coverImageData
        }

        do {
            try modelContext.save()
            CheckpointWidgetSync.sync(using: modelContext)
            dismiss()
        } catch {
            assertionFailure("Failed saving game: \(error)")
        }
    }

    private func applySuggestion(_ suggestion: RawgGameSuggestion) {
        selectedSuggestionID = suggestion.id
        title = suggestion.name
        rawgSuggestions = []
        rawgStatusMessage = nil

        guard let coverURL = suggestion.coverURL else { return }

        Task {
            guard let imageData = try? await RawgAPI.downloadImageData(from: coverURL) else { return }
            await MainActor.run {
                coverImageData = imageData
            }
        }
    }

    @MainActor
    private func fetchSuggestionsIfNeeded(for rawText: String) async {
        let query = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedSuggestionID = nil

        guard query.count >= 2 else {
            rawgSuggestions = []
            isLoadingSuggestions = false
            rawgStatusMessage = nil
            return
        }

        guard RawgAPI.hasAPIKey else {
            rawgSuggestions = []
            isLoadingSuggestions = false
            rawgStatusMessage = "RAWG API key is missing in app config."
            return
        }

        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            guard query == title.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            rawgSuggestions = try await RawgAPI.searchGames(query: query)
            rawgStatusMessage = rawgSuggestions.isEmpty ? "No matches found in RAWG." : nil
        } catch is CancellationError {
            // Ignore: this happens naturally while user keeps typing.
            return
        } catch {
            rawgSuggestions = []
            rawgStatusMessage = "Couldn't search games right now. Please try again."
        }
    }
}

private enum QuietConsoleTheme {
    static let accent = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.39, green: 0.77, blue: 0.71, alpha: 1)
            : UIColor(red: 0.12, green: 0.47, blue: 0.43, alpha: 1)
    })

    static let secondaryAction = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.27, blue: 0.34, alpha: 1)
            : UIColor(red: 0.80, green: 0.84, blue: 0.88, alpha: 1)
    })

    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let primaryFill = Color(uiColor: .secondarySystemGroupedBackground)
    static let secondaryFill = Color(uiColor: .tertiarySystemGroupedBackground)
    static let elevatedFill = Color(uiColor: .secondarySystemBackground)
    static let subtleText = Color(uiColor: .secondaryLabel)
    static let cardBorder = Color.primary.opacity(0.08)
    static let cardShadow = Color.black.opacity(0.12)
    static let activityFill = accent.opacity(0.16)
    static let activityText = accent
}

private enum QuietSurfaceStyle {
    case primary
    case secondary
    case elevated

    var fill: Color {
        switch self {
        case .primary:
            return QuietConsoleTheme.primaryFill
        case .secondary:
            return QuietConsoleTheme.secondaryFill
        case .elevated:
            return QuietConsoleTheme.elevatedFill
        }
    }

    var borderOpacity: Double {
        switch self {
        case .primary:
            return 0.08
        case .secondary:
            return 0.06
        case .elevated:
            return 0.1
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .primary:
            return 8
        case .secondary:
            return 4
        case .elevated:
            return 10
        }
    }
}

private struct QuietSurfaceModifier: ViewModifier {
    let style: QuietSurfaceStyle
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(style.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(style.borderOpacity), lineWidth: 1)
            )
            .shadow(color: QuietConsoleTheme.cardShadow.opacity(style == .secondary ? 0.35 : 0.55), radius: style.shadowRadius, x: 0, y: 3)
    }
}

private extension View {
    func quietSurface(_ style: QuietSurfaceStyle, cornerRadius: CGFloat) -> some View {
        modifier(QuietSurfaceModifier(style: style, cornerRadius: cornerRadius))
    }
}

private enum QuickResumeCopy {
    static let latestNotePrefix = CheckpointResumeCopy.latestNotePrefix
    static let latestNoteFallback = CheckpointResumeCopy.latestNoteFallback

    static func pendingTasksSummary(pendingCount: Int) -> String {
        CheckpointResumeCopy.pendingTasksSummary(pendingCount: pendingCount)
    }
}

private enum GameActivityFormatter {
    static func lastActivityLabel(for lastPlayedAt: Date?, now: Date = .now, calendar: Calendar = .current) -> String {
        CheckpointActivityFormatter.lastActivityLabel(for: lastPlayedAt, now: now, calendar: calendar)
    }
}

private enum Haptics {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension GameResource {
    var normalizedURL: URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        return URL(string: withScheme)
    }

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            return trimmed
        }
        return normalizedURL?.host ?? urlString
    }

    var kindLabel: String {
        guard let host = normalizedURL?.host?.lowercased() else { return "Link" }
        if host.contains("youtube.com") || host.contains("youtu.be") {
            return "YouTube"
        }
        if host.contains("fandom.com") || host.contains("wiki") || host.contains("ign.com") || host.contains("gamespot.com") {
            return "Guide"
        }
        return "Link"
    }

    var kindTint: Color {
        switch kindLabel {
        case "YouTube":
            return .red
        case "Guide":
            return QuietConsoleTheme.accent
        default:
            return .secondary
        }
    }

    var lastUsedLabel: String {
        if let lastUsedAt {
            return "Opened \(lastUsedAt.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Not opened yet"
    }
}

private struct RawgGameSuggestion: Identifiable, Decodable {
    let id: Int
    let name: String
    let backgroundImage: String?

    var coverURL: URL? {
        guard let backgroundImage else { return nil }
        return URL(string: backgroundImage)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case backgroundImage = "background_image"
    }
}

private enum RawgAPI {
    static var hasAPIKey: Bool {
        (apiKey?.isEmpty == false)
    }

    static func searchGames(query: String) async throws -> [RawgGameSuggestion] {
        guard let apiKey else { return [] }

        var components = URLComponents(string: "https://api.rawg.io/api/games")
        components?.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "page_size", value: "6")
        ]

        guard let url = components?.url else { return [] }
        let (data, response) = try await URLSession.shared.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            if let apiError = try? JSONDecoder().decode(RawgErrorResponse.self, from: data) {
                throw RawgAPIError.server(apiError.error)
            }
            throw RawgAPIError.server("RAWG returned status \(http.statusCode).")
        }

        let decoded = try JSONDecoder().decode(RawgSearchResponse.self, from: data)
        return decoded.results
    }

    static func downloadImageData(from url: URL) async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    }

    private static var apiKey: String? {
        if let fromInfo = Bundle.main.object(forInfoDictionaryKey: "RAWG_API_KEY") as? String,
           fromInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            return fromInfo
        }
        // MVP fallback to avoid build-config issues while wiring the project.
        return "be9c6d8902014726b0efa64c108308e4"
    }

    private struct RawgSearchResponse: Decodable {
        let results: [RawgGameSuggestion]
    }

    private struct RawgErrorResponse: Decodable {
        let error: String
    }

    private enum RawgAPIError: LocalizedError {
        case server(String)

        var errorDescription: String? {
            switch self {
            case .server(let message):
                return message
            }
        }
    }
}

private enum BackupImportMode {
    case merge
    case replace
}

private struct CheckpointBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct CheckpointBackup: Codable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let exportedAt: Date
    let games: [GameSnapshot]

    struct GameSnapshot: Codable {
        let id: UUID
        let title: String
        let createdAt: Date
        let lastPlayedAt: Date?
        let coverImageData: Data?
        let notes: [NoteSnapshot]
        let tasks: [TaskSnapshot]
        let resources: [ResourceSnapshot]

        private enum CodingKeys: String, CodingKey {
            case id
            case title
            case createdAt
            case lastPlayedAt
            case coverImageData
            case notes
            case tasks
            case resources
        }

        init(
            id: UUID,
            title: String,
            createdAt: Date,
            lastPlayedAt: Date?,
            coverImageData: Data?,
            notes: [NoteSnapshot],
            tasks: [TaskSnapshot],
            resources: [ResourceSnapshot]
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
            coverImageData = try container.decodeIfPresent(Data.self, forKey: .coverImageData)
            notes = try container.decode([NoteSnapshot].self, forKey: .notes)
            tasks = try container.decode([TaskSnapshot].self, forKey: .tasks)
            resources = try container.decodeIfPresent([ResourceSnapshot].self, forKey: .resources) ?? []
        }
    }

    struct NoteSnapshot: Codable {
        let id: UUID
        let createdAt: Date
        let text: String
        let photoData: Data?

        private enum CodingKeys: String, CodingKey {
            case id
            case createdAt
            case text
            case photoData
        }

        init(id: UUID, createdAt: Date, text: String, photoData: Data?) {
            self.id = id
            self.createdAt = createdAt
            self.text = text
            self.photoData = photoData
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
            text = try container.decode(String.self, forKey: .text)
            photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        }
    }

    struct TaskSnapshot: Codable {
        let id: UUID
        let createdAt: Date
        let text: String
        let isDone: Bool
    }

    struct ResourceSnapshot: Codable {
        let id: UUID
        let createdAt: Date
        let title: String
        let urlString: String
        let lastUsedAt: Date?
    }

    static func from(games: [Game]) -> CheckpointBackup {
        CheckpointBackup(
            schemaVersion: currentSchemaVersion,
            exportedAt: .now,
            games: games.map { game in
                GameSnapshot(
                    id: game.id,
                    title: game.title,
                    createdAt: game.createdAt,
                    lastPlayedAt: game.lastPlayedAt,
                    coverImageData: game.coverImageData,
                    notes: game.notes.map { note in
                        NoteSnapshot(
                            id: note.id,
                            createdAt: note.createdAt,
                            text: note.text,
                            photoData: note.photoData
                        )
                    },
                    tasks: game.tasks.map { task in
                        TaskSnapshot(
                            id: task.id,
                            createdAt: task.createdAt,
                            text: task.text,
                            isDone: task.isDone
                        )
                    },
                    resources: game.resources.map { resource in
                        ResourceSnapshot(
                            id: resource.id,
                            createdAt: resource.createdAt,
                            title: resource.title,
                            urlString: resource.urlString,
                            lastUsedAt: resource.lastUsedAt
                        )
                    }
                )
            }
        )
    }

    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    static func decode(from data: Data) throws -> CheckpointBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CheckpointBackup.self, from: data)
    }
}

private extension Date {
    static var backupFileStamp: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: .now)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Game.self, GameNote.self, GameTask.self, GameResource.self], inMemory: true)
}
