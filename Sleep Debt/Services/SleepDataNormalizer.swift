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

    // MARK: 1. Process HealthKit Samples
    /// Filters for "asleep" samples, then splits them by the day boundary.
    static func process(
        samples: [HKCategorySample],
        boundaryHour: Int,
        timeZone: TimeZone
    ) -> [AnchoredIntervalSegment] {
        let asleepSamples = filterAsleep(samples: samples)
        return splitByBoundary(samples: asleepSamples, boundaryHour: boundaryHour, timeZone: timeZone)
    }

    // MARK: - Private Pipeline Steps

    /// Filters HKCategorySamples to include only "asleep" types.
    private static func filterAsleep(samples: [HKCategorySample]) -> [HKCategorySample] {
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

    /// Splits intervals by the day boundary and assigns each segment to a sleep day.
    private static func splitByBoundary(
        samples: [HKCategorySample],
        boundaryHour: Int,
        timeZone: TimeZone
    ) -> [AnchoredIntervalSegment] {
        var segments: [AnchoredIntervalSegment] = []
        let dayIdFormatter = ISO8601DateFormatter()
        dayIdFormatter.formatOptions = [.withFullDate]

        for sample in samples {
            var calendar = Calendar.current
            calendar.timeZone = timeZone

            var currentStart = sample.startDate

            while currentStart < sample.endDate {
                let nextBoundary = getNextBoundary(for: currentStart, boundaryHour: boundaryHour, calendar: calendar)
                let segmentEnd = min(sample.endDate, nextBoundary)

                // Determine which sleep day this segment belongs to based on its END time.
                let sleepDayForSegment = getSleepDay(for: segmentEnd, boundaryHour: boundaryHour, calendar: calendar)
                let dayId = dayIdFormatter.string(from: sleepDayForSegment)

                let segment = AnchoredIntervalSegment(
                    uuid: sample.uuid,
                    dayId: dayId,
                    start: currentStart,
                    end: segmentEnd,
                    sourceBundleId: sample.sourceRevision.source.bundleIdentifier
                )
                segments.append(segment)

                currentStart = segmentEnd
            }
        }

        return segments
    }

    // MARK: - Date Helpers

    private static func getSleepDay(for date: Date, boundaryHour: Int, calendar: Calendar) -> Date {
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

    private static func getNextBoundary(for date: Date, boundaryHour: Int, calendar: Calendar) -> Date {
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
