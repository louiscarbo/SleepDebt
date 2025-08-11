import Foundation
import HealthKit

// MARK: - Normalization Data Structures

/// A continuous interval of sleep from a single source, with its original UUID.
struct SleepInterval {
    let uuid: UUID
    let start: Date
    let end: Date
    let sourceBundleId: String
}

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

    // MARK: 1. Filter Asleep Samples
    /// Filters HKCategorySamples to include only "asleep" types and preserves the UUID.
    static func filterAsleep(samples: [HKCategorySample]) -> [SleepInterval] {
        let acceptedValues: Set<HKCategoryValueSleepAnalysis> = [
            .asleepCore, .asleepDeep, .asleepREM, .asleepUnspecified
        ]

        return samples.compactMap { sample in
            guard let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value),
                  acceptedValues.contains(sleepValue) else {
                return nil
            }
            return SleepInterval(
                uuid: sample.uuid,
                start: sample.startDate,
                end: sample.endDate,
                sourceBundleId: sample.sourceRevision.source.bundleIdentifier
            )
        }
    }

    // MARK: 2. Split by Day Boundary
    /// Splits intervals by the day boundary and assigns each segment to a sleep day.
    /// This is done *before* merging to preserve data granularity for storage.
    static func splitByBoundary(intervals: [SleepInterval], boundaryHour: Int, timeZone: TimeZone) -> [AnchoredIntervalSegment] {
        var segments: [AnchoredIntervalSegment] = []
        let dayIdFormatter = ISO8601DateFormatter()
        dayIdFormatter.formatOptions = [.withFullDate]

        for interval in intervals {
            var calendar = Calendar.current
            calendar.timeZone = timeZone

            var currentStart = interval.start

            while currentStart < interval.end {
                let nextBoundary = getNextBoundary(for: currentStart, boundaryHour: boundaryHour, calendar: calendar)
                let segmentEnd = min(interval.end, nextBoundary)

                // Determine which sleep day this segment belongs to based on its END time.
                let sleepDayForSegment = getSleepDay(for: segmentEnd, boundaryHour: boundaryHour, calendar: calendar)
                let dayId = dayIdFormatter.string(from: sleepDayForSegment)

                // Note: A single HKCategorySample can be split into multiple segments across
                // day boundaries. They will share the same UUID. This is expected.
                // When a UUID is deleted, all its segments must be deleted.
                let segment = AnchoredIntervalSegment(
                    uuid: interval.uuid,
                    dayId: dayId,
                    start: currentStart,
                    end: segmentEnd,
                    sourceBundleId: interval.sourceBundleId
                )
                segments.append(segment)

                currentStart = segmentEnd
            }
        }

        return segments
    }

    // MARK: 3. Merge & Coalesce (For Aggregation)
    /// Merges overlapping intervals and coalesces adjacent intervals with a small gap.
    /// **Note:** This is used during the aggregation phase (calculating total minutes for a day),
    /// not during the initial normalization-for-storage phase, as it loses original UUIDs.
    static func mergeAndCoalesce(intervals: [SleepInterval], gapSeconds: TimeInterval = 120) -> [SleepInterval] {
        guard !intervals.isEmpty else { return [] }

        let sortedIntervals = intervals.sorted { $0.start < $1.start }

        var merged: [SleepInterval] = []
        guard var currentMerge = sortedIntervals.first else { return [] }

        for i in 1..<sortedIntervals.count {
            let next = sortedIntervals[i]
            let gap = next.start.timeIntervalSince(currentMerge.end)

            if gap <= gapSeconds {
                let newEnd = max(currentMerge.end, next.end)
                currentMerge = SleepInterval(
                    uuid: currentMerge.uuid, // UUID is not truly representative here.
                    start: currentMerge.start,
                    end: newEnd,
                    sourceBundleId: currentMerge.sourceBundleId
                )
            } else {
                merged.append(currentMerge)
                currentMerge = next
            }
        }
        merged.append(currentMerge)

        return merged
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
