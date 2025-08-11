import Foundation
import SwiftData

// MARK: - DebtEngine
final class DebtEngine {
    private var modelContext: ModelContext
    private let calendar: Calendar
    private let dayIdFormatter: ISO8601DateFormatter

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.calendar = Calendar.current
        self.dayIdFormatter = ISO8601DateFormatter()
        self.dayIdFormatter.formatOptions = [.withFullDate]
    }

    // MARK: - Public API

    /// Rebuilds the chain of daily summaries, calculating cumulative debt.
    /// This is the main entry point after data has been synced from HealthKit.
    func rebuildChain(from dirtyDayIds: Set<String>) throws {
        guard !dirtyDayIds.isEmpty else { return }

        // 1. Find the earliest day that needs re-computation.
        let earliestDate = dirtyDayIds.compactMap { dayIdFormatter.date(from: $0) }.min() ?? .now

        // 2. Determine the start of the rebuild window (32 days prior to be safe).
        let rebuildStartDate = calendar.date(byAdding: .day, value: -32, to: earliestDate)!
        let today = calendar.startOfDay(for: .now)

        // 3. Fetch all potentially relevant summaries and user settings in one go.
        let settings = try getSettings()
        var summariesByDayId = try fetchSummaries(from: rebuildStartDate, to: today)

        // 4. Iterate from the start of the window to today, re-calculating each day.
        var currentDate = rebuildStartDate
        var previousDaySummary: DailySummary? = fetchPreviousDaySummary(for: rebuildStartDate)

        while currentDate <= today {
            let dayId = dayIdFormatter.string(from: currentDate)

            // Generate the day's core metrics (actual sleep, delta)
            let currentDaySummary = try generateDaySummary(dayId: dayId, settings: settings)
            summariesByDayId[dayId] = currentDaySummary

            if let summary = currentDaySummary {
                // This is a day with data, calculate cumulative debt.
                let previousDebt = previousDaySummary?.cumulativeDebtMinutes ?? 0
                summary.cumulativeDebtMinutes = max(0, previousDebt + summary.deltaMinutes)
                previousDaySummary = summary
            } else {
                // This is a "No Data" day. The chain is broken.
                // The next day with data will start its cumulative debt from 0 (or its previous day's value).
                // If this day had a summary before, it should have been deleted by generateDaySummary.
                // We check the fetched map for the previous day with data.
                var tempDate = calendar.date(byAdding: .day, value: -1, to: currentDate)!
                while tempDate >= rebuildStartDate {
                    let tempDayId = dayIdFormatter.string(from: tempDate)
                    if let prev = summariesByDayId[tempDayId] {
                        previousDaySummary = prev
                        break
                    }
                    tempDate = calendar.date(byAdding: .day, value: -1, to: tempDate)!
                }
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        try modelContext.save()
    }

    /// Computes the 14-day sleep debt for the headline UI.
    func computeDebt14(asOf today: Date) throws -> Int {
        let windowStartDate = calendar.date(byAdding: .day, value: -13, to: today)!

        let predicate = #Predicate<DailySummary> { summary in
            summary.date >= windowStartDate && summary.date <= today && summary.hasData
        }
        let descriptor = FetchDescriptor<DailySummary>(predicate: predicate)
        let summaries = try modelContext.fetch(descriptor)

        let totalDelta = summaries.reduce(0) { $0 + $1.deltaMinutes }

        return max(0, totalDelta)
    }

    /// Computes the percentile-based comparison label.
    func computeBaselineLabel(asOf today: Date) throws -> String? {
        // Implementation for Phase 6.
        // For now, return nil as per spec until sufficient history logic is built.
        return nil
    }

    // MARK: - Private Helpers

    /// Generates or updates a DailySummary for a single day based on stored SleepEpisodes.
    private func generateDaySummary(dayId: String, settings: UserSettings) throws -> DailySummary? {
        let date = dayIdFormatter.date(from: dayId)!
        let predicate = #Predicate<SleepEpisode> { $0.anchoredDayId == dayId }
        let episodes = try modelContext.fetch(FetchDescriptor(predicate: predicate))

        // First, fetch the existing summary for the day.
        let existingSummary = try fetchSummary(for: dayId)

        // If there are no episodes, any existing summary should be deleted.
        if episodes.isEmpty {
            if let summaryToDelete = existingSummary {
                modelContext.delete(summaryToDelete)
            }
            return nil
        }

        // We have episodes, so we need a summary. Calculate its values.
        let totalSeconds = episodes.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
        let actualMinutes = Int(totalSeconds / 60)
        let cappedActualMinutes = min(actualMinutes, settings.goalMinutes + 240)
        let deltaMinutes = settings.goalMinutes - cappedActualMinutes
        let sourceCount = Set(episodes.map { $0.sourceBundleId }).count

        // Now, either update the existing summary or create a new one.
        if let summary = existingSummary {
            // Update existing summary
            summary.hasData = true
            summary.actualMinutes = cappedActualMinutes
            summary.deltaMinutes = deltaMinutes
            summary.sourceCount = sourceCount
            summary.updatedAt = .now
            return summary
        } else {
            // Create new summary
            let newSummary = DailySummary(
                dayId: dayId,
                date: date,
                hasData: true,
                actualMinutes: cappedActualMinutes,
                deltaMinutes: deltaMinutes,
                cumulativeDebtMinutes: 0, // This will be calculated in the rebuild chain
                dataQuality: .complete,   // Placeholder
                sourceCount: sourceCount
            )
            modelContext.insert(newSummary)
            return newSummary
        }
    }

    private func fetchSummaries(from startDate: Date, to endDate: Date) throws -> [String: DailySummary] {
        let predicate = #Predicate<DailySummary> { $0.date >= startDate && $0.date <= endDate }
        let summaries = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        return Dictionary(uniqueKeysWithValues: summaries.map { ($0.dayId, $0) })
    }

    private func fetchSummary(for dayId: String) throws -> DailySummary? {
        let predicate = #Predicate<DailySummary> { $0.dayId == dayId }
        let summaries = try modelContext.fetch(FetchDescriptor(predicate: predicate))
        return summaries.first
    }

    private func fetchPreviousDaySummary(for date: Date) -> DailySummary? {
        let prevDate = calendar.date(byAdding: .day, value: -1, to: date)!
        let prevDayId = dayIdFormatter.string(from: prevDate)
        // This is a fetch, so it's okay to throw. But the call site doesn't expect it.
        // A simple try? is fine here.
        return try? fetchSummary(for: prevDayId)
    }

    private func getSettings() throws -> UserSettings {
        // A real app would have a more robust way to handle missing settings.
        if let settings = try modelContext.fetch(FetchDescriptor<UserSettings>()).first {
            return settings
        }
        let defaultSettings = UserSettings()
        modelContext.insert(defaultSettings)
        return defaultSettings
    }
}
