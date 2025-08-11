import Foundation
import SwiftData

// MARK: - Settings
@Model final class UserSettings {
    @Attribute(.unique) var id: String = "singleton"
    var goalMinutes: Int // default 480
    var dayBoundaryHour: Int // default 4
    var comparisonEnabled: Bool // true, auto-hidden if insufficient data
    var notifications: NotificationPrefs
    var lastSyncDate: Date?
    var hkQueryAnchorData: Data? // serialized HKQueryAnchor
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
    var dailyPreferredHour: Int?
    var dailyPreferredMinute: Int?
    var thresholdAlertsEnabled: Bool = false
    var thresholdsMinutes: [Int] = [120, 300, 480] // 2h, 5h, 8h

    var dailyPreferredTime: DateComponents? {
        get {
            guard let hour = dailyPreferredHour, let minute = dailyPreferredMinute else { return nil }
            return DateComponents(hour: hour, minute: minute)
        }
        set {
            dailyPreferredHour = newValue?.hour
            dailyPreferredMinute = newValue?.minute
        }
    }

    // Custom init to set the default time
    init() {
        self.dailySummaryEnabled = true
        self.thresholdAlertsEnabled = false
        self.thresholdsMinutes = [120, 300, 480]
        self.dailyPreferredTime = DateComponents(hour: 8, minute: 0)
    }
}

// MARK: - Per-day summary (post-merge)
@Model final class DailySummary {
    @Attribute(.unique) var dayId: String // "YYYY-MM-DD@anchor4"
    var date: Date // midnight of local day (anchor date)
    var hasData: Bool // at least one asleep interval after normalization
    var actualMinutes: Int // 0 if only inBed; undefined days → not stored
    var deltaMinutes: Int // ideal - actual
    var cumulativeDebtMinutes: Int // running clamp(≥0) for display
    var dataQuality: DataQuality
    var sourceCount: Int // number of distinct bundleIds that contributed
    var createdAt: Date
    var updatedAt: Date

    init(dayId: String, date: Date, hasData: Bool, actualMinutes: Int,
         deltaMinutes: Int, cumulativeDebtMinutes: Int,
         dataQuality: DataQuality, sourceCount: Int) {
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
    case complete // standard asleep intervals present
    case partial  // odd caps/merges applied; or stage gaps filled
    case none     // should not exist as a stored summary; a “no data day” is absent
}

// MARK: - Optional raw episode store (90-day rolling)
@Model final class SleepEpisode {
    @Attribute(.unique) var uuid: UUID
    var start: Date
    var end: Date
    var sourceBundleId: String
    var anchoredDayId: String // for fast grouping
    var createdAt: Date

    init(uuid: UUID, start: Date, end: Date, sourceBundleId: String, anchoredDayId: String) {
        self.uuid = uuid
        self.start = start
        self.end = end
        self.sourceBundleId = sourceBundleId
        self.anchoredDayId = anchoredDayId
        self.createdAt = .now
    }
}
