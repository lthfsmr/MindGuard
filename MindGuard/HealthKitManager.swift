//
//  HealthKitManager.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 13/11/26.
//


import Foundation
import HealthKit
import Combine

final class HealthKitManager: ObservableObject {

    static let shared = HealthKitManager()

    private let healthStore = HKHealthStore()

    private let heartRateType = HKObjectType.quantityType(
        forIdentifier: .heartRate
    )!

    private var observerQuery: HKObserverQuery?

    private var isStarted = false

    private let engine = EmotionalEngine.shared

    @Published private(set) var latestHeartRate: Double = 0

    @Published private(set) var latestSampleDate: Date?

    @Published private(set) var emotionalState: EmotionalState = .calibrating

    @Published private(set) var isAuthorized = false

    @Published private(set) var errorMessage: String?

    private var lastProcessedDate: Date? {
        get {
            UserDefaults.standard.object(
                forKey: "mindguard.lastProcessedHeartRateDate"
            ) as? Date
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: "mindguard.lastProcessedHeartRateDate"
            )
        }
    }

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws {

        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(
                domain: "MindGuard",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "HealthKit is not available."
                ]
            )
        }

        let readTypes: Set<HKObjectType> = [
            heartRateType
        ]

        try await healthStore.requestAuthorization(
            toShare: [],
            read: readTypes
        )

        await MainActor.run {
            self.isAuthorized = true
        }
    }

    // MARK: - Start Monitoring

    func start() async {

        guard !isStarted else {
            return
        }

        do {

            try await requestAuthorization()

            isStarted = true

            startObserverQuery()

            enableBackgroundDelivery()

            fetchHeartRateSamples()

            print("MindGuard HealthKit monitoring started")

        } catch {

            errorMessage = error.localizedDescription

            print("HealthKit error:", error)
        }
    }

    // MARK: - Background Delivery

    private func enableBackgroundDelivery() {

        healthStore.enableBackgroundDelivery(
            for: heartRateType,
            frequency: .immediate
        ) { success, error in

            if let error {
                print("Background delivery error:", error)
                return
            }

            print(
                "Background delivery enabled:",
                success
            )
        }
    }

    // MARK: - Observer Query

    private func startObserverQuery() {

        guard observerQuery == nil else {
            return
        }

        let query = HKObserverQuery(
            sampleType: heartRateType,
            predicate: nil
        ) { [weak self] _, completionHandler, error in

            guard let self else {
                completionHandler()
                return
            }

            if let error {
                print("Observer query error:", error)
                completionHandler()
                return
            }

            print("New heart rate data detected")

            self.fetchHeartRateSamples {
                completionHandler()
            }
        }

        observerQuery = query

        healthStore.execute(query)
    }

    // MARK: - Fetch Samples

    private func fetchHeartRateSamples(
        completion: (() -> Void)? = nil
    ) {

        let startDate = lastProcessedDate

        let predicate: NSPredicate?

        if let startDate {

            predicate = HKQuery.predicateForSamples(
                withStart: startDate,
                end: nil,
                options: .strictStartDate
            )

        } else {

            let yesterday = Calendar.current.date(
                byAdding: .day,
                value: -1,
                to: Date()
            )!

            predicate = HKQuery.predicateForSamples(
                withStart: yesterday,
                end: nil,
                options: .strictStartDate
            )
        }

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: startDate != nil
        )

        let limit = startDate == nil
            ? 20
            : HKObjectQueryNoLimit

        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: predicate,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { [weak self] _, samples, error in

            defer {
                completion?()
            }

            guard let self else {
                return
            }

            if let error {
                print("Heart rate query error:", error)
                return
            }

            guard let samples = samples as? [HKQuantitySample],
                  !samples.isEmpty else {

                print("No heart rate samples available")
                return
            }

            // Initial fetch returns newest 20 samples.
            // Reverse them to process chronologically.
            let orderedSamples: [HKQuantitySample] = startDate == nil
                ? Array(samples.reversed())
                : samples
            
            let isInitialFetch = startDate == nil

            for sample in orderedSamples {

                self.processSample(
                    sample,
                    notify: !isInitialFetch
                )
            }
        }

        healthStore.execute(query)
    }

    // MARK: - Process Heart Rate

    private func processSample(
        _ sample: HKQuantitySample,
        notify: Bool
    ) {

        let heartRate = sample.quantity.doubleValue(
            for: HKUnit.count().unitDivided(
                by: HKUnit.minute()
            )
        )

        let timestamp = sample.endDate

        if let lastProcessedDate,
           timestamp <= lastProcessedDate {
            return
        }

        let metrics = EmotionalMetrics(
            heartRate: heartRate,
            timestamp: timestamp
        )

        let state = engine.process(metrics)

        lastProcessedDate = timestamp

        DispatchQueue.main.async {

            self.latestHeartRate = heartRate

            self.latestSampleDate = timestamp

            self.emotionalState = state
        }

        print("Heart Rate:", heartRate)
        print("Timestamp:", timestamp)
        print("Emotional State:", state)

        if notify && engine.shouldSendNotification() {

            NotificationManager.shared.sendMindfulnessNotification()
        }
    }
}
