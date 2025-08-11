import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var localGoal: Int

    // To manage the stepper value, which works with Doubles.
    @State private var stepperValue: Double

    init() {
        // This is a bit of a hack to initialize state from environment.
        // In a real app, you might pass the initial value directly.
        let initialGoal = 480 // A default fallback
        _localGoal = State(initialValue: initialGoal)
        _stepperValue = State(initialValue: Double(initialGoal))
    }

    var body: some View {
        Form {
            Section(header: Text("Personalization")) {
                VStack(alignment: .leading) {
                    Text("Sleep Goal")
                    Text(formatMinutes(localGoal))
                        .font(.title)
                        .fontWeight(.bold)
                }

                Stepper("Adjust in 15-minute steps", value: $stepperValue, in: 240...720, step: 15)
                    .onChange(of: stepperValue) {
                        localGoal = Int(stepperValue)
                    }
            }

            Section(header: Text("Data Source")) {
                Link("Manage Health Permissions", destination: URL(string: "x-apple-health://")!)
            }

            Section {
                 Button("Save and Recalculate") {
                    Task {
                        await appState.updateGoal(newGoalMinutes: localGoal)
                    }
                }
                .disabled(localGoal == appState.userGoalMinutes)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            // Sync the local state with the app state when the view appears.
            self.localGoal = appState.userGoalMinutes
            self.stepperValue = Double(appState.userGoalMinutes)
        }
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours) hours, \(minutes) minutes"
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        // This won't work perfectly without a mock AppState,
        // but it's good for basic layout.
        NavigationStack {
            SettingsView()
        }
    }
}
