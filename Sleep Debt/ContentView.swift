//
//  ContentView.swift
//  Sleep Debt
//
//  Created by Louis Carbo Estaque on 10/08/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }
            NavigationStack { DetailsView() }
                .tabItem { Label("Details", systemImage: "list.bullet") }
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState(container: try! ModelContainer(for: SleepDebtSchemaV1.self)))
}
