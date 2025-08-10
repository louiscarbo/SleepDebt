import Foundation
import SwiftData

// MARK: - Settings
@Model
final class UserSettings {
    @Attribute(.unique) var id: String = "singleton"
    var goalMinutes: Int
    var dayBoundaryHour: Int
    var comparisonEnabled: Bool
    var notifications: NotificationPrefs
    var lastSyncDate: Date?
    var hkQueryAnchorData: Data?
    var createdAt: Date
    var updatedAt: Date

    init(goalMinutes: Int = 480,
         dayBoundaryHour: Int = 4,
         comparisonEnabled: Bool = true,
         notifications: NotificationPrefs = .init(),
         lastSyncDate: Date? = nil,
         hkQueryAnchorData: Data? = nil) {
        self.goalMinutes = goalMinutes
        self.dayBoundaryHour = dayBoundaryHour
        self.comparisonEnabled = comparisonEnabled
        self.notifications = notifications
        self.lastSyncDate = lastSyncDate
        self.hkQueryAnchorData = hkQueryAnchorData
        self.createdAt = .now
        self.updatedAt = .now
    }
}

struct NotificationPrefs: Codable, Hashable {
    var dailySummaryEnabled: Bool = true
    var dailyPreferredTime: DateComponents? = DateComponents(hour: 8, minute: 0)
    var thresholdAlertsEnabled: Bool = false
    var thresholdsMinutes: [Int] = [120, 300, 480]
}

// MARK: - Per-day summary
@Model
final class DailySummary {
    @Attribute(.unique) var dayId: String
    var date: Date
    var hasData: Bool
    var actualMinutes: Int
    var deltaMinutes: Int
    var cumulativeDebtMinutes: Int
    var dataQuality: DataQuality
    var sourceCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(dayId: String,
         date: Date,
         hasData: Bool,
         actualMinutes: Int,
         deltaMinutes: Int,
         cumulativeDebtMinutes: Int,
         dataQuality: DataQuality,
         sourceCount: Int) {
        self.dayId = dayId
        self.date = date
        self.hasData = hasData
        self.actualMinutes = actualMinutes
        self.deltaMinutes = deltaMinutes
        self.cumulativeDebtMinutes = cumulativeDebtMinutes
        self.dataQuality = dataQuality
        self.sourceCount = sourceCount
        self.createdAt = .now
        self.updatedAt = .now
    }
}

enum DataQuality: Int, Codable {
    case complete
    case partial
    case none
}

// MARK: - Raw sleep episode
@Model
final class SleepEpisode {
    var start: Date
    var end: Date
    var sourceBundleId: String
    var anchoredDayId: String
    var createdAt: Date

    init(start: Date,
         end: Date,
         sourceBundleId: String,
         anchoredDayId: String) {
        self.start = start
        self.end = end
        self.sourceBundleId = sourceBundleId
        self.anchoredDayId = anchoredDayId
        self.createdAt = .now
    }
}

// MARK: - Schema & Migration
enum SleepDebtSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [UserSettings.self, DailySummary.self, SleepEpisode.self]
    }
}

enum SleepDebtMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SleepDebtSchemaV1.self]
    }

    static var stages: [MigrationStage] { [] }
}
