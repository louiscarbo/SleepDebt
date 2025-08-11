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
    @State private var selectedPoint: ChartPoint?
    @State private var selectedPointLocation: CGPoint?

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

            if let selectedPoint {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .annotation(position: .top, alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selectedPoint.date, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(formatMinutes(selectedPoint.value))
                                .font(.headline.bold())
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemBackground))
                                .shadow(radius: 2)
                        )
                    }
            }
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
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                self.selectedPointLocation = value.location
                                if let date = proxy.value(atX: value.location.x, as: Date.self) {
                                    let calendar = Calendar.current
                                    let closestPoint = chartPoints.min(by: { a, b in
                                        let aDist = abs(calendar.dateComponents([.day], from: a.date, to: date).day ?? Int.max)
                                        let bDist = abs(calendar.dateComponents([.day], from: b.date, to: date).day ?? Int.max)
                                        return aDist < bDist
                                    })
                                    self.selectedPoint = closestPoint
                                }
                            }
                            .onEnded { _ in
                                self.selectedPoint = nil
                                self.selectedPointLocation = nil
                            }
                    )
            }
        }
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = abs(totalMinutes % 60)
        return "\(hours)h \(minutes)m"
    }
}
