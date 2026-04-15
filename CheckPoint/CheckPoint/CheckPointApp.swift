import SwiftUI
import SwiftData

@main
struct CheckPointApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Game.self, GameNote.self, GameTask.self, GameResource.self])
    }
}
