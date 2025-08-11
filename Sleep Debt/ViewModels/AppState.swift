import Foundation
import SwiftUI
import SwiftData
import HealthKit

@Observable
@MainActor
final class AppState {
    // MARK: - Published Properties
    var headlineDebtMinutes: Int = 0
    var debtLabel: String? = nil
    var lastSync: Date? = nil
    var chartPoints: [ChartPoint] = []
    var todaySummary: String = "Today: ..."
    var userGoalMinutes: Int = 480 // Default 8h

    // MARK: - Dependencies
    private var modelContext: ModelContext
    private let healthStoreManager: HealthStoreManager
    private let debtEngine: DebtEngine
    private let calendar = Calendar.current

    // MARK: - Initialization
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.healthStoreManager = HealthStoreManager()
        self.debtEngine = DebtEngine(modelContext: modelContext)
    }

    // MARK: - Public API

    func initialLoad() async {
        do {
            try await healthStoreManager.requestAuthorization()
            await refresh()
            if let settings = try? getSettings() {
                userGoalMinutes = settings.goalMinutes
            }
        } catch {
            print("HealthKit authorization failed: \(error)")
            // In a real app, we would set an error state here to show in the UI.
        }
    }

    func refresh() async {
        do {
            let settings = try getSettings()

            // 1. Sync raw data from HealthKit
            let syncInterval = try await syncHealthKitData(settings: settings)

            // 2. Process sessions and re-aggregate debt if needed
            if let interval = syncInterval {
                let sessionProcessor = SessionProcessor(modelContext: modelContext)
                let dirtyDayIds = try sessionProcessor.process(dateRange: interval, settings: settings)

                if !dirtyDayIds.isEmpty {
                    try debtEngine.rebuildChain(from: dirtyDayIds)
                }
            }

            // 3. Update all published properties for the UI
            try await updatePublishedProperties()
            print("Sync, aggregation, and UI update complete.")

        } catch {
            print("Error during refresh: \(error)")
        }
    }

    func updateGoal(newGoalMinutes: Int) async {
        do {
            let settings = try getSettings()
            guard settings.goalMinutes != newGoalMinutes else { return }
            settings.goalMinutes = newGoalMinutes
            self.userGoalMinutes = newGoalMinutes
            try modelContext.save()

            await forceFullReaggregation()
        } catch {
            print("Failed to update goal: \(error)")
        }
    }

    // Note: Updating the day boundary would follow the same pattern.
    // func updateDayBoundary(newBoundaryHour: Int) async { ... }

    // MARK: - Private Logic

    private func updatePublishedProperties() async throws {
        let today = calendar.startOfDay(for: .now)

        self.headlineDebtMinutes = try debtEngine.computeDebt14(asOf: today)
        self.debtLabel = try debtEngine.computeBaselineLabel(asOf: today)

        let settings = try getSettings()
        self.lastSync = settings.lastSyncDate

        // Chart Points (14-day rolling debt)
        let historyStartDate = calendar.date(byAdding: .day, value: -27, to: today)! // Need 14 days of chart + 13 days of history
        let historyPredicate = #Predicate<DailySummary> { $0.date >= historyStartDate && $0.date <= today }
        let historySummaries = try modelContext.fetch(FetchDescriptor(predicate: historyPredicate))
        let deltaByDay = Dictionary(uniqueKeysWithValues: historySummaries.map { (calendar.startOfDay(for: $0.date), $0.deltaMinutes) })

        var newChartPoints: [ChartPoint] = []
        for i in 0..<14 {
            let chartDate = calendar.date(byAdding: .day, value: -(13 - i), to: today)!
            var rollingDebt = 0
            for j in 0..<14 {
                let historyDate = calendar.date(byAdding: .day, value: -j, to: chartDate)!
                rollingDebt += deltaByDay[historyDate] ?? 0
            }
            newChartPoints.append(ChartPoint(date: chartDate, value: max(0, rollingDebt)))
        }
        self.chartPoints = newChartPoints

        // Today Summary Pill
        if let todaySummaryData = historySummaries.last(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            let actualHours = todaySummaryData.actualMinutes / 60
            let actualRemainderMinutes = todaySummaryData.actualMinutes % 60
            let goalHours = settings.goalMinutes / 60
            self.todaySummary = "Today: \(actualHours)h \(actualRemainderMinutes)m / \(goalHours)h"
        } else {
            self.todaySummary = "Today: No Data"
        }
    }

    private func forceFullReaggregation() async {
        do {
            print("Starting full re-aggregation due to settings change...")
            let allEpisodes = try modelContext.fetch(FetchDescriptor<SleepEpisode>())
            let allDayIds = Set(allEpisodes.map { $0.anchoredDayId })

            if !allDayIds.isEmpty {
                try debtEngine.rebuildChain(from: allDayIds)
            }

            try await updatePublishedProperties()
            print("Full re-aggregation complete.")
        } catch {
            print("Failed to force full re-aggregation: \(error)")
        }
    }

    private func getSettings() throws -> UserSettings {
        if let settings = try modelContext.fetch(FetchDescriptor<UserSettings>()).first {
            return settings
        }
        let defaultSettings = UserSettings()
        modelContext.insert(defaultSettings)
        try modelContext.save()
        return defaultSettings
    }

    // MARK: - HealthKit Sync & Persistence

    private func syncHealthKitData(settings: UserSettings) async throws -> DateInterval? {
        let lastAnchorData = settings.hkQueryAnchorData
        let anchor: HKQueryAnchor? = lastAnchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }

        let fetchResult = try await healthStoreManager.runAnchoredFetch(anchor: anchor)
        var changedDates: [Date] = []

        if !fetchResult.deleted.isEmpty {
            let deletedUUIDs = fetchResult.deleted.map { $0.uuid }
            let predicate = #Predicate<SleepEpisode> { deletedUUIDs.contains($0.uuid) }
            let episodesToDelete = try modelContext.fetch(FetchDescriptor(predicate: predicate))

            for episode in episodesToDelete {
                changedDates.append(episode.start)
                modelContext.delete(episode)
            }
        }

        if !fetchResult.added.isEmpty {
            let asleepSamples = SleepDataNormalizer.filterAsleep(samples: fetchResult.added)
            let dayIdFormatter = ISO8601DateFormatter()
            dayIdFormatter.formatOptions = [.withFullDate]

            for sample in asleepSamples {
                // Use a temporary day ID based on start time; this will be corrected by the SessionProcessor.
                let tempSleepDay = SleepDataNormalizer.getSleepDay(for: sample.startDate, boundaryHour: settings.dayBoundaryHour, calendar: calendar)
                let tempDayId = dayIdFormatter.string(from: tempSleepDay)

                let newEpisode = SleepEpisode(
                    uuid: sample.uuid,
                    start: sample.startDate,
                    end: sample.endDate,
                    sourceBundleId: sample.sourceRevision.source.bundleIdentifier,
                    anchoredDayId: tempDayId
                )
                modelContext.insert(newEpisode)
                changedDates.append(sample.startDate)
                changedDates.append(sample.endDate)
            }
        }

        guard !changedDates.isEmpty else {
            return nil // No changes
        }

        let newAnchorData = try NSKeyedArchiver.archivedData(withRootObject: fetchResult.newAnchor, requiringSecureCoding: true)
        settings.hkQueryAnchorData = newAnchorData
        settings.lastSyncDate = .now

        if modelContext.hasChanges {
            try modelContext.save()
        }

        // Return a date interval covering all changes
        let minDate = changedDates.min()!
        let maxDate = changedDates.max()!
        // Add a buffer to the date range to catch sessions that might be just outside
        let startDate = calendar.date(byAdding: .day, value: -1, to: minDate)!
        let endDate = calendar.date(byAdding: .day, value: 1, to: maxDate)!

        return DateInterval(start: startDate, end: endDate)
    }
}
