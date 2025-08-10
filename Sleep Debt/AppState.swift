import Foundation
import Observation
import SwiftData

@Observable class AppState {
    private let container: ModelContainer
    private let debtEngine: DebtEngine

    var headlineDebtMinutes: Int = 0
    var debtLabel: String? = nil
    var lastSync: Date? = nil
    var chartPoints: [ChartPoint] = []
    var todaySummary: DailySummary?

    init(container: ModelContainer) {
        self.container = container
        self.debtEngine = DebtEngine(container: container)
    }

    func refresh() {
        Task {
            self.headlineDebtMinutes = (try? debtEngine.computeDebt14()) ?? 0
            self.chartPoints = (try? debtEngine.buildChartPoints(windowDays: 30)) ?? []
        }
    }
}
