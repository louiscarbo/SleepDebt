import Foundation
import HealthKit

// MARK: - Normalization Data Structures

/// A segment of a sleep interval, anchored to a specific "sleep day".
/// The original UUID is preserved to allow finding and deleting.
struct AnchoredIntervalSegment {
    let uuid: UUID
    let dayId: String // "YYYY-MM-DD"
    let start: Date
    let end: Date
    let sourceBundleId: String
}

// MARK: - Normalization Pipeline
final class SleepDataNormalizer {

    // MARK: - Public Helpers

    /// Filters HKCategorySamples to include only "asleep" types.
    static func filterAsleep(samples: [HKCategorySample]) -> [HKCategorySample] {
        let acceptedValues: Set<HKCategoryValueSleepAnalysis> = [
            .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified
        ]

        return samples.filter { sample in
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) else {
                return false
            }
            return acceptedValues.contains(sleepValue)
        }
    }

    /// Groups sleep episodes into sessions based on a time gap threshold.
    static func groupIntoSessions(episodes: [SleepEpisode], gapThreshold: TimeInterval = 3600) -> [[SleepEpisode]] {
        guard !episodes.isEmpty else { return [] }

        let sortedEpisodes = episodes.sorted { $0.start < $1.start }

        var sessions: [[SleepEpisode]] = []
        var currentSession: [SleepEpisode] = [sortedEpisodes.first!]

        for i in 1..<sortedEpisodes.count {
            let prevEpisode = currentSession.last!
            let currentEpisode = sortedEpisodes[i]

            let gap = currentEpisode.start.timeIntervalSince(prevEpisode.end)
            if gap < gapThreshold {
                currentSession.append(currentEpisode)
            } else {
                sessions.append(currentSession)
                currentSession = [currentEpisode]
            }
        }
        sessions.append(currentSession)
        return sessions
    }


    // MARK: - Date Helpers

    static func getSleepDay(for date: Date, boundaryHour: Int, calendar: Calendar) -> Date {
        let startOfCalendarDay = calendar.startOfDay(for: date)
        guard let boundaryTime = calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: date) else {
            return startOfCalendarDay
        }

        if date > boundaryTime {
            return startOfCalendarDay
        } else {
            return calendar.date(byAdding: .day, value: -1, to: startOfCalendarDay)!
        }
    }

    static func getNextBoundary(for date: Date, boundaryHour: Int, calendar: Calendar) -> Date {
        let startOfCalendarDay = calendar.startOfDay(for: date)
        guard let boundaryOnThisDay = calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: date) else {
            return calendar.date(byAdding: .day, value: 1, to: startOfCalendarDay)!
        }

        if date < boundaryOnThisDay {
            return boundaryOnThisDay
        } else {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: date)!
            return calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: nextDay)!
        }
    }
}
