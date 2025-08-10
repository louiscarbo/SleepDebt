import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Query private var settings: [UserSettings]

    var body: some View {
        if let setting = settings.first {
            Form {
                Stepper(value: binding(for: \.goalMinutes, in: setting), step: 15, in: 240...720) {
                    Text("Sleep goal: \(setting.goalMinutes) min")
                }
                Stepper(value: binding(for: \.dayBoundaryHour, in: setting), in: 0...12) {
                    Text("Day boundary: \(setting.dayBoundaryHour):00")
                }
            }
        } else {
            Text("No settings")
        }
    }

    private func binding<T>(for keyPath: WritableKeyPath<UserSettings, T>, in object: UserSettings) -> Binding<T> {
        Binding(get: { object[keyPath: keyPath] }, set: { object[keyPath: keyPath] = $0 })
    }
}

#Preview {
    SettingsView()
        .environment(AppState(container: try! ModelContainer(for: SleepDebtSchemaV1.self)))
}
