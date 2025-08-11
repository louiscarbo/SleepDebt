import Foundation
import HealthKit

// MARK: - HealthStoreManager (actor)
actor HealthStoreManager {
    let healthStore = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        [HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!]
    }

    // MARK: - Authorization
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.healthDataNotAvailable
        }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Background & Observers
    func enableBackgroundDelivery() async throws {
        try await healthStore.enableBackgroundDelivery(for: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, frequency: .immediate)
    }

    func startObservers(updateHandler: @escaping () -> Void) {
        let query = HKObserverQuery(sampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, predicate: nil) { (query, completionHandler, error) in
            if let error = error {
                print("Observer query failed: \(error.localizedDescription)")
                completionHandler()
                return
            }

            print("Observer query triggered an update.")
            updateHandler()
            completionHandler()
        }
        healthStore.execute(query)
    }

    // MARK: - Data Fetching
    func runAnchoredFetch(anchor: HKQueryAnchor? = nil) async throws -> FetchResult {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { (query, addedSamples, deletedObjects, newAnchor, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let addedCategorySamples = addedSamples as? [HKCategorySample] ?? []
                let deletedCategoryObjects = deletedObjects ?? []

                guard let finalAnchor = newAnchor else {
                    // This case should not happen in a successful query.
                    // If it does, something is fundamentally wrong with the HealthKit interaction.
                    continuation.resume(throwing: HealthError.unexpectedAnchorNil)
                    return
                }

                let result = FetchResult(
                    added: addedCategorySamples,
                    deleted: deletedCategoryObjects,
                    newAnchor: finalAnchor
                )
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - Supporting Types
struct FetchResult {
    let added: [HKCategorySample]
    let deleted: [HKDeletedObject]
    let newAnchor: HKQueryAnchor
}

enum HealthError: Error {
    case healthDataNotAvailable
    case unexpectedAnchorNil
    case authorizationFailed // This could be more granular if needed
}
