import SwiftUI
import SwiftData

@main
struct SleepDebtApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserSettings.self,
            DailySummary.self,
            SleepEpisode.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var appState: AppState

    init() {
        let container = sharedModelContainer
        // The underscore is used to set the initial value of a @State property wrapper.
        self._appState = State(initialValue: AppState(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(sharedModelContainer)
        .environment(appState)
    }
}
