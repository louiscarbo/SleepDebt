import Foundation
import SwiftData

final class SessionProcessor {
    private let modelContext: ModelContext
    private let calendar: Calendar
    private let dayIdFormatter: ISO8601DateFormatter

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.calendar = Calendar.current
        self.dayIdFormatter = ISO8601DateFormatter()
        self.dayIdFormatter.formatOptions = [.withFullDate]
    }

    /// Processes all sleep episodes within a given date range,
    /// groups them into sessions, and re-assigns their `anchoredDayId`.
    ///
    /// - Parameter dateRange: The range of dates to process.
    /// - Returns: A set of "dirty" day IDs that need to be re-aggregated.
    func process(dateRange: DateInterval, settings: UserSettings) throws -> Set<String> {
        let episodes = try fetchEpisodes(in: dateRange)
        if episodes.isEmpty {
            return []
        }

        var dirtyDayIds = Set<String>()
        let sessions = SleepDataNormalizer.groupIntoSessions(episodes: episodes)

        for session in sessions {
            guard let lastEpisode = session.last else { continue }

            let sessionEndDate = lastEpisode.end
            let sleepDayForSession = SleepDataNormalizer.getSleepDay(
                for: sessionEndDate,
                boundaryHour: settings.dayBoundaryHour,
                calendar: calendar
            )
            let newDayId = dayIdFormatter.string(from: sleepDayForSession)

            for episode in session {
                if episode.anchoredDayId != newDayId {
                    dirtyDayIds.insert(episode.anchoredDayId)
                    episode.anchoredDayId = newDayId
                    dirtyDayIds.insert(newDayId)
                }
            }
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }

        // We need to remove the temporary dayId "" if it exists
        dirtyDayIds.remove("")

        return dirtyDayIds
    }

    private func fetchEpisodes(in dateRange: DateInterval) throws -> [SleepEpisode] {
        let start = dateRange.start
        let end = dateRange.end
        // We want to fetch all episodes that overlap with the given date range.
        // The condition for two intervals [A, B] and [C, D] to overlap is A < D and C < B.
        let predicate = #Predicate<SleepEpisode> { episode in
            episode.start < end && episode.end > start
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.start)])
        return try modelContext.fetch(descriptor)
    }
}
