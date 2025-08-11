import SwiftUI
import Charts

// This could also be in a Models file, but since it's only used by the chart,
// defining it here is acceptable for this project's scope.
struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Int
}

struct DebtHistoryChartView: View {
    let chartPoints: [ChartPoint]

    var body: some View {
        Chart(chartPoints, id: \.date) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(.blue)

            // Add a point mark for better visibility on tap
            PointMark(
                x: .value("Date", point.date),
                y: .value("Value", point.value)
            )
            .foregroundStyle(.blue)
            .symbolSize(100)
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    let totalMinutes = value.as(Int.self) ?? 0
                    let hours = totalMinutes / 60
                    let minutes = abs(totalMinutes % 60)
                    Text("\(hours)h \(minutes)m")
                }
            }
        }
        .chartYAxisLabel("14-Day Rolling Debt")
        .frame(height: 200)
    }
}
