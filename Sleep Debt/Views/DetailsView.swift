import SwiftUI
import SwiftData
import Charts

struct DetailsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            DebtHistoryChartView(chartPoints: appState.chartPoints)
                .padding()

            DailySummaryListView(timeframeDays: 14) // Fixed to 14 days
        }
        .navigationTitle("Details")
    }
}

struct DailySummaryListView: View {
    let timeframeDays: Int
    @Query private var summaries: [DailySummary]

    init(timeframeDays: Int) {
        self.timeframeDays = timeframeDays
        let today = Calendar.current.startOfDay(for: .now)
        let startDate = Calendar.current.date(byAdding: .day, value: -(timeframeDays - 1), to: today)!

        let predicate = #Predicate<DailySummary> { summary in
            summary.date >= startDate && summary.date <= today
        }
        self._summaries = Query(filter: predicate, sort: \.date, order: .reverse)
    }

    var body: some View {
        List(summaries) { summary in
            HStack {
                VStack(alignment: .leading) {
                    Text(summary.date, style: .date)
                        .fontWeight(.bold)
                    Text("Slept: \(formatMinutes(summary.actualMinutes))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(deltaText(summary.deltaMinutes))
                    .foregroundColor(deltaColor(summary.deltaMinutes))
            }
        }
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }

    private func deltaText(_ delta: Int) -> String {
        let hours = abs(delta) / 60
        let minutes = abs(delta) % 60
        let sign = delta >= 0 ? "+" : "-"
        return "\(sign)\(hours)h \(minutes)m"
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta > 0 {
            return .orange // Deficit
        } else if delta < 0 {
            return .green // Surplus
        } else {
            return .primary // Balanced
        }
    }
}
