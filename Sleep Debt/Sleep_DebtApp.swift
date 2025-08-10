//
//  Sleep_DebtApp.swift
//  Sleep Debt
//
//  Created by Louis Carbo Estaque on 10/08/2025.
//

import SwiftUI
import SwiftData

@main
struct Sleep_DebtApp: App {
    let sharedModelContainer: ModelContainer
    @State private var appState: AppState

    init() {
        let config = ModelConfiguration(migrationPlan: SleepDebtMigrationPlan.self,
                                        isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: SleepDebtSchemaV1.self,
                                               configurations: [config])
            self.sharedModelContainer = container
            _appState = State(initialValue: AppState(container: container))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
