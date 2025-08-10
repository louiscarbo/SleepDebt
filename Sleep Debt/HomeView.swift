import SwiftUI
import Charts

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("\(formatMinutes(appState.headlineDebtMinutes))")
                .font(.system(size: 48, weight: .bold))
            if let label = appState.debtLabel {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let lastSync = appState.lastSync {
                Text("Last sync: \(lastSync, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Chart(appState.chartPoints, id: \.date) { point in
                LineMark(x: .value("Date", point.date), y: .value("Debt", point.debtMinutes))
            }
            .frame(height: 200)
            Spacer()
        }
        .padding()
        .onAppear { appState.refresh() }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }
}

#Preview {
    HomeView()
        .environment(AppState(container: try! ModelContainer(for: SleepDebtSchemaV1.self)))
}
