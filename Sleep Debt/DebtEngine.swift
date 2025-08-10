import Foundation
import SwiftData

struct ChartPoint {
    let date: Date
    let debtMinutes: Int
}

final class DebtEngine {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Aggregate a day into DailySummary based on stored episodes
    func aggregateDay(dayId: String) throws -> DailySummary? {
        let context = ModelContext(container)
        let request = FetchDescriptor<SleepEpisode>(predicate: #Predicate { $0.anchoredDayId == dayId })
        let episodes = try context.fetch(request)
        guard !episodes.isEmpty else { return nil }
        let actualMinutes = episodes.reduce(0) { $0 + Int($1.end.timeIntervalSince($1.start) / 60) }
        let settings = try context.fetch(FetchDescriptor<UserSettings>()).first ?? UserSettings()
        let delta = settings.goalMinutes - actualMinutes
        let summary = DailySummary(dayId: dayId,
                                   date: episodes.first!.start,
                                   hasData: true,
                                   actualMinutes: actualMinutes,
                                   deltaMinutes: delta,
                                   cumulativeDebtMinutes: 0,
                                   dataQuality: .complete,
                                   sourceCount: Set(episodes.map { $0.sourceBundleId }).count)
        context.insert(summary)
        try context.save()
        return summary
    }

    /// Rebuild cumulative debt from a starting dayId backwards
    func rebuildFrom(dayId: String, lookbackDays: Int = 32) throws {
        let context = ModelContext(container)
        let fetch = FetchDescriptor<DailySummary>(sortBy: [SortDescriptor(\.date)])
        var summaries = try context.fetch(fetch)
        summaries.sort { $0.date < $1.date }
        var prevDebt = 0
        for summary in summaries {
            summary.cumulativeDebtMinutes = max(0, prevDebt + summary.deltaMinutes)
            prevDebt = summary.cumulativeDebtMinutes
        }
        try context.save()
    }

    /// Compute 14-day debt from last 14 days with data
    func computeDebt14(asOf date: Date = .now) throws -> Int {
        let context = ModelContext(container)
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -13, to: date) else { return 0 }
        let predicate = #Predicate<DailySummary> { summary in
            summary.date >= start && summary.date <= date && summary.hasData
        }
        let fetch = FetchDescriptor<DailySummary>(predicate: predicate)
        let summaries = try context.fetch(fetch)
        return summaries.reduce(0) { $0 + $1.deltaMinutes }
    }

    func buildChartPoints(windowDays: Int) throws -> [ChartPoint] {
        let context = ModelContext(container)
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -windowDays + 1, to: .now) else { return [] }
        let predicate = #Predicate<DailySummary> { $0.date >= start }
        let fetch = FetchDescriptor<DailySummary>(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        let summaries = try context.fetch(fetch)
        return summaries.map { ChartPoint(date: $0.date, debtMinutes: $0.cumulativeDebtMinutes) }
    }

    func computeBaselineLabel(asOf date: Date = .now) throws -> String? {
        // Placeholder baseline: return nil for now
        return nil
    }
}
