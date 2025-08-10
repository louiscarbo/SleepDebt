import Foundation
import HealthKit

struct Interval {
    let start: Date
    let end: Date
    let sourceId: String
}

/// Accepts only asleep samples
func filterAsleep(_ samples: [HKCategorySample]) -> [Interval] {
    samples.compactMap { sample in
        switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
        case .asleepCore?, .asleepDeep?, .asleepREM?, .asleepUnspecified?:
            return Interval(start: sample.startDate, end: sample.endDate, sourceId: sample.sourceRevision.source.bundleIdentifier)
        default:
            return nil
        }
    }
}

/// Merge overlapping intervals and coalesce small gaps
func mergeAndCoalesce(_ intervals: [Interval], gapSeconds: Int = 120) -> [Interval] {
    guard !intervals.isEmpty else { return [] }
    let sorted = intervals.sorted { $0.start < $1.start }
    var result: [Interval] = []
    var current = sorted[0]
    for interval in sorted.dropFirst() {
        if interval.start.timeIntervalSince(current.end) <= TimeInterval(gapSeconds) {
            let newEnd = max(current.end, interval.end)
            current = Interval(start: current.start, end: newEnd, sourceId: current.sourceId)
        } else {
            result.append(current)
            current = interval
        }
    }
    result.append(current)
    return result
}

/// Split intervals by boundary hour and tag with dayId
struct IntervalSegment {
    let dayId: String
    let start: Date
    let end: Date
    let sourceId: String
}

func splitByBoundary(_ intervals: [Interval], boundaryHour: Int, timeZone: TimeZone = .current) -> [IntervalSegment] {
    var segments: [IntervalSegment] = []
    let calendar = Calendar.current
    for interval in intervals {
        var cursorStart = interval.start
        while cursorStart < interval.end {
            let dayComponents = calendar.dateComponents(in: timeZone, from: cursorStart)
            var boundaryComponents = DateComponents()
            boundaryComponents.year = dayComponents.year
            boundaryComponents.month = dayComponents.month
            boundaryComponents.day = dayComponents.day
            boundaryComponents.hour = boundaryHour
            boundaryComponents.minute = 0
            boundaryComponents.second = 0
            guard let boundary = calendar.date(from: boundaryComponents) else { break }
            let nextBoundary = calendar.date(byAdding: .day, value: 1, to: boundary)!
            let segmentEnd = min(interval.end, nextBoundary)
            let dayString = DateFormatter.dayFormatter.string(from: boundary)
            let dayId = "\(dayString)@anchor\(boundaryHour)"
            segments.append(IntervalSegment(dayId: dayId, start: cursorStart, end: segmentEnd, sourceId: interval.sourceId))
            cursorStart = segmentEnd
        }
    }
    return segments
}

private extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
