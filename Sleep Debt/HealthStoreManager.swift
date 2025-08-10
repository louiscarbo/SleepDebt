import Foundation
import HealthKit

actor HealthStoreManager {
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
    }

    func enableBackgroundDelivery() async throws {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        try await healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate)
    }

    func startObservers() async throws {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, completion, error in
            guard error == nil else {
                completion()
                return
            }
            Task {
                _ = try? await self?.runAnchoredFetch()
                completion()
            }
        }
        healthStore.execute(query)
    }

    func runAnchoredFetch(anchor: HKQueryAnchor? = nil) async throws -> FetchResult {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(type: sleepType, predicate: nil, anchor: anchor, limit: HKObjectQueryNoLimit) { _, samplesOrNil, deletedOrNil, newAnchor, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let samples = samplesOrNil as? [HKCategorySample] ?? []
                let deleted = deletedOrNil ?? []
                let result = FetchResult(added: samples, deleted: deleted, newAnchor: newAnchor)
                continuation.resume(returning: result)
            }
            healthStore.execute(query)
        }
    }
}

struct FetchResult {
    let added: [HKCategorySample]
    let deleted: [HKDeletedObject]
    let newAnchor: HKQueryAnchor
}
