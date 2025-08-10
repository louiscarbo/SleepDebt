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
    var sharedModelContainer: ModelContainer = {
        let config = ModelConfiguration(migrationPlan: SleepDebtMigrationPlan.self,
                                        isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: SleepDebtSchemaV1.self,
                                      configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
