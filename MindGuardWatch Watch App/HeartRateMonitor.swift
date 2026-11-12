//
//  HeartRateMonitor.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//

import Foundation
import HealthKit
import Combine

final class HeartRateMonitor: NSObject, ObservableObject {

    @Published private(set) var heartRate: Double = 0

    @Published private(set) var isMonitoring = false

    private let healthStore = HKHealthStore()

    private var workoutSession: HKWorkoutSession?

    private var workoutBuilder: HKLiveWorkoutBuilder?

    private let heartRateType = HKQuantityType.quantityType(
        forIdentifier: .heartRate
    )!

    func requestAuthorization() async throws {

        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(
                domain: "MindGuard",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "HealthKit is not available on this device."
                ]
            )
        }

        let typesToRead: Set<HKObjectType> = [
            heartRateType
        ]

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]

        try await healthStore.requestAuthorization(
            toShare: typesToShare,
            read: typesToRead
        )
    }

    func startMonitoring() {

        guard !isMonitoring else {
            return
        }

        do {

            let configuration = HKWorkoutConfiguration()

            configuration.activityType = .mindAndBody

            configuration.locationType = .indoor

            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )

            let builder = session.associatedWorkoutBuilder()

            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )

            session.delegate = self

            builder.delegate = self

            workoutSession = session

            workoutBuilder = builder

            let startDate = Date()

            session.startActivity(with: startDate)

            builder.beginCollection(withStart: startDate) {
                success, error in

                if let error {
                    print("Begin collection error:", error)
                }

                DispatchQueue.main.async {
                    self.isMonitoring = success
                }
            }

        } catch {

            print("Workout session error:", error)
        }
    }

    func stopMonitoring() {

        guard let workoutSession,
              let workoutBuilder else {
            return
        }

        workoutSession.end()

        workoutBuilder.endCollection(withEnd: Date()) {
            success, error in

            if let error {
                print("End collection error:", error)
            }

            workoutBuilder.finishWorkout { _, error in

                if let error {
                    print("Finish workout error:", error)
                }

                DispatchQueue.main.async {
                    self.isMonitoring = false
                }
            }
        }
    }

    private func handleHeartRate(_ statistics: HKStatistics) {

        guard let quantity = statistics.mostRecentQuantity() else {
            return
        }

        let value = quantity.doubleValue(
            for: HKUnit.count().unitDivided(by: .minute())
        )

        DispatchQueue.main.async {

            self.heartRate = value

            WatchConnectivitySender.shared.sendHeartRate(value)
        }
    }
}

extension HeartRateMonitor: HKWorkoutSessionDelegate {

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {

        print("Workout state:", toState.rawValue)
    }

    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {

        print("Workout session failed:", error)

        DispatchQueue.main.async {
            self.isMonitoring = false
        }
    }
}

extension HeartRateMonitor: HKLiveWorkoutBuilderDelegate {

    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {

        guard collectedTypes.contains(heartRateType) else {
            return
        }

        guard let statistics = workoutBuilder.statistics(
            for: heartRateType
        ) else {
            return
        }

        handleHeartRate(statistics)
    }

    func workoutBuilderDidCollectEvent(
        _ workoutBuilder: HKLiveWorkoutBuilder
    ) {}
}
