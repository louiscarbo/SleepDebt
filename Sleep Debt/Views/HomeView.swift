import SwiftUI
import Charts

struct HomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                header

                DebtHistoryChartView(chartPoints: appState.chartPoints)
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

// The DebtChartView and ChartPoint structs have been moved to DebtHistoryChartView.swift
// to create a reusable component.
