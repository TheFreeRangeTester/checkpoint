import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct QuickCheckpointRequest: Identifiable {
    let id = UUID()
    var gameID: UUID?
    var startsWithPhoto = false
}

struct QuickCheckpointComposer: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let games: [Game]
    let startsWithPhoto: Bool
    var onSave: () -> Void = {}
    @State private var selectedGameID: UUID?
    @State private var summary = ""
    @State private var objective = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var pin = false
    @State private var showingPhotoPicker = false
    @State private var isLoadingPhoto = false
    @State private var errorMessage: String?
    @FocusState private var summaryFocused: Bool

    init(games: [Game], preferredGameID: UUID? = nil, startsWithPhoto: Bool = false, onSave: @escaping () -> Void = {}) {
        self.games = games
        self.startsWithPhoto = startsWithPhoto
        self.onSave = onSave
        _selectedGameID = State(initialValue: preferredGameID ?? games.first?.id)
    }

    private var selectedGame: Game? { games.first { $0.id == selectedGameID } }
    private var canSave: Bool {
        selectedGame != nil && !isLoadingPhoto &&
        CheckpointPolicy.canSave(summary: summary, objective: objective, photoData: photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if games.count > 1 {
                        Picker("Game", selection: $selectedGameID) {
                            ForEach(games) { game in
                                Text(game.title).tag(Optional(game.id))
                            }
                        }
                    } else if let selectedGame {
                        Label(selectedGame.title, systemImage: "gamecontroller")
                    }
                }

                Section {
                    TextField("Beat the boss. Next stop: the northern city.", text: $summary, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($summaryFocused)
                        .accessibilityLabel("What happened?")
                    TextField("Next objective (optional)", text: $objective, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("What happened?")
                } footer: {
                    Text("A sentence or a screenshot is enough. Add an objective to put it first next time.")
                }

                Section {
                    Button {
                        summaryFocused = false
                        showingPhotoPicker = true
                    } label: {
                        Label(photoData == nil ? "Start from a Screenshot" : "Change Screenshot", systemImage: "photo.badge.plus")
                    }
                    if isLoadingPhoto {
                        ProgressView("Loading screenshot…")
                    }
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Checkpoint screenshot")
                        Button("Remove Screenshot", role: .destructive) {
                            photoItem = nil
                            self.photoData = nil
                        }
                    }
                    if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photoData != nil {
                        Toggle("Pin for next time", isOn: $pin)
                    }
                } footer: {
                    Text("Maps and inventory screens work too. No text required.")
                }
            }
            .navigationTitle("Quick Checkpoint")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.bold)
                        .disabled(!canSave)
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItem, matching: .images)
            .task {
                if startsWithPhoto {
                    showingPhotoPicker = true
                } else {
                    summaryFocused = true
                }
            }
            .task(id: photoItem) {
                guard let photoItem else { return }
                isLoadingPhoto = true
                defer { isLoadingPhoto = false }
                do {
                    guard let data = try await photoItem.loadTransferable(type: Data.self),
                          let optimized = CheckpointPhoto.optimized(data) else {
                        throw CocoaError(.fileReadCorruptFile)
                    }
                    try Task.checkCancellation()
                    photoData = optimized
                } catch is CancellationError {
                    return
                } catch {
                    errorMessage = "Couldn't load this image. Choose another screenshot or try again."
                }
            }
            .alert("Checkpoint", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .tint(QuietConsoleTheme.accent)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(CheckpointPolicy.canSave(summary: summary, objective: objective, photoData: photoData) || isLoadingPhoto)
    }

    private func save() {
        guard canSave, let selectedGame else { return }
        do {
            try CheckpointPolicy.save(for: selectedGame, summary: summary, objective: objective, photoData: photoData, pin: pin, in: modelContext)
            CheckpointWidgetSync.sync(using: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSave()
            dismiss()
        } catch {
            errorMessage = "Couldn't save your checkpoint. Your draft is still here. Please try again."
        }
    }
}

enum CheckpointPhoto {
    static func optimized(_ data: Data) -> Data? {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(1, 1800 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, floor(image.size.width * scale)), height: max(1, floor(image.size.height * scale)))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.jpegData(compressionQuality: 0.85)
    }
}
