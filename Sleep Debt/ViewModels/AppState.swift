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
            let dirtyDayIds = try await syncHealthKitData()

            if !dirtyDayIds.isEmpty {
                try debtEngine.rebuildChain(from: dirtyDayIds)
            }

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

        // Chart Points (last 30 days)
        let chartStartDate = calendar.date(byAdding: .day, value: -29, to: today)!
        let predicate = #Predicate<DailySummary> { $0.date >= chartStartDate && $0.date <= today }
        let descriptor = FetchDescriptor<DailySummary>(predicate: predicate, sortBy: [SortDescriptor(\.date)])
        let summaries = try modelContext.fetch(descriptor)
        self.chartPoints = summaries.map { ChartPoint(date: $0.date, debtMinutes: $0.cumulativeDebtMinutes) }

        // Today Summary Pill
        if let todaySummaryData = summaries.last(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
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

    private func syncHealthKitData() async throws -> Set<String> {
        let settings = try getSettings()
        let lastAnchorData = settings.hkQueryAnchorData
        let anchor: HKQueryAnchor? = lastAnchorData.flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: $0) }

        let fetchResult = try await healthStoreManager.runAnchoredFetch(anchor: anchor)
        var dirtyDayIds = Set<String>()

        if !fetchResult.deleted.isEmpty {
            let deletedUUIDs = fetchResult.deleted.map { $0.uuid }
            let predicate = #Predicate<SleepEpisode> { deletedUUIDs.contains($0.uuid) }
            let episodesToDelete = try modelContext.fetch(FetchDescriptor(predicate: predicate))
            for episode in episodesToDelete {
                dirtyDayIds.insert(episode.anchoredDayId)
                modelContext.delete(episode)
            }
        }

        if !fetchResult.added.isEmpty {
            let segments = SleepDataNormalizer.process(samples: fetchResult.added, boundaryHour: settings.dayBoundaryHour, timeZone: .current)
            for segment in segments {
                let newEpisode = SleepEpisode(uuid: segment.uuid, start: segment.start, end: segment.end, sourceBundleId: segment.sourceBundleId, anchoredDayId: segment.dayId)
                // Using an upsert-like pattern
                modelContext.insert(newEpisode)
                dirtyDayIds.insert(segment.dayId)
            }
        }

        let newAnchorData = try NSKeyedArchiver.archivedData(withRootObject: fetchResult.newAnchor, requiringSecureCoding: true)
        settings.hkQueryAnchorData = newAnchorData
        settings.lastSyncDate = .now

        if modelContext.hasChanges {
            try modelContext.save()
        }

        return dirtyDayIds
    }
}
