import SwiftUI
import SwiftData
import Charts

struct DetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTimeframe: Int = 30
    let timeframes = [7, 14, 30, 60, 90]

    var body: some View {
        VStack {
            Picker("Timeframe", selection: $selectedTimeframe) {
                ForEach(timeframes, id: \.self) { days in
                    Text("\(days) days").tag(days)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            DetailsChartView(timeframeDays: selectedTimeframe)

            DailySummaryListView(timeframeDays: selectedTimeframe)
        }
        .navigationTitle("Details")
    }
}

struct DetailsChartView: View {
    let timeframeDays: Int
    @Query private var summaries: [DailySummary]

    init(timeframeDays: Int) {
        self.timeframeDays = timeframeDays
        let today = Calendar.current.startOfDay(for: .now)
        let startDate = Calendar.current.date(byAdding: .day, value: -(timeframeDays - 1), to: today)!

        let predicate = #Predicate<DailySummary> { summary in
            summary.date >= startDate && summary.date <= today
        }
        self._summaries = Query(filter: predicate, sort: \.date)
    }

    var body: some View {
        VStack {
            if summaries.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar.xaxis")
                    .frame(height: 200)
            } else {
                Chart(summaries) { summary in
                    LineMark(
                        x: .value("Date", summary.date, unit: .day),
                        y: .value("Cumulative Debt", summary.cumulativeDebtMinutes)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
                .padding()
            }
        }
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
