import SwiftUI
import Charts

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header

                DebtChartView(chartPoints: appState.chartPoints)
                    .padding(.horizontal)

                todayPill

                Spacer()

                footer
            }
            .navigationTitle("Sleep Debt")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        Task {
                            await appState.refresh()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                Task {
                    await appState.initialLoad()
                }
            }
        }
    }

    private var header: some View {
        VStack {
            Text(formatMinutes(appState.headlineDebtMinutes))
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(debtColor(for: appState.headlineDebtMinutes))

            if let label = appState.debtLabel {
                Text(label)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
        }
    }

    private var todayPill: some View {
        Text(appState.todaySummary)
            .font(.footnote)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(16)
    }

    private var footer: some View {
        VStack {
            if let lastSync = appState.lastSync {
                Text("Last sync: \(lastSync, style: .relative) ago")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            NavigationLink("View Details") {
                DetailsView()
            }
        }
        .padding(.bottom)
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours)h \(minutes)m"
    }

    private func debtColor(for minutes: Int) -> Color {
        switch minutes {
        case 0...120: // 0-2h
            return .green
        case 121...300: // 2-5h
            return .orange
        default: // >5h
            return .red
        }
    }
}

struct DebtChartView: View {
    let chartPoints: [ChartPoint]

    var body: some View {
        Chart(chartPoints, id: \.date) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Debt", point.debtMinutes)
            )
            .foregroundStyle(.blue)

            // Add a point mark for better visibility on tap
            PointMark(
                x: .value("Date", point.date),
                y: .value("Debt", point.debtMinutes)
            )
            .foregroundStyle(.blue)
            .symbolSize(100)
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 200)
    }
}

// Add a placeholder for ChartPoint if it's not globally defined
// and accessible here. Assuming it's in DebtEngine.swift and accessible.
struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let debtMinutes: Int
}
