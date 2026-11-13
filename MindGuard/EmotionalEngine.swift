//
//  EmotionalEngine.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 13/11/26.
//

import Foundation


final class EmotionalEngine {

    static let shared = EmotionalEngine()

    private init() {
        baselineSamples = UserDefaults.standard.array(
            forKey: baselineSamplesKey
        ) as? [Double] ?? []

        baselineHeartRate = UserDefaults.standard.object(
            forKey: baselineHeartRateKey
        ) as? Double

        if baselineHeartRate != nil {
            currentState = .normal
        }
    }

    // MARK: - Baseline

    private var baselineSamples: [Double] = []

    private var baselineHeartRate: Double?

    private let baselineSampleCount = 10

    private let baselineSamplesKey = "mindguard.baselineSamples"

    private let baselineHeartRateKey = "mindguard.baselineHeartRate"

    // MARK: - Detection

    private let minimumElevation: Double = 15

    private let elevationPercentage: Double = 1.20

    private let requiredElevatedSamples = 2

    private var consecutiveElevatedSamples = 0

    private var lastSampleDate: Date?

    // MARK: - Notification

    private let notificationCooldown: TimeInterval = 1800

    private var lastNotificationDate: Date? {
        get {
            UserDefaults.standard.object(
                forKey: "mindguard.lastNotificationDate"
            ) as? Date
        }
        set {
            UserDefaults.standard.set(
                newValue,
                forKey: "mindguard.lastNotificationDate"
            )
        }
    }

    // MARK: - State

    private(set) var currentState: EmotionalState = .calibrating

    var calibrationProgress: Double {
        min(
            Double(baselineSamples.count) / Double(baselineSampleCount),
            1.0
        )
    }

    var currentBaseline: Double? {
        baselineHeartRate
    }

    // MARK: - Process

    func process(_ metrics: EmotionalMetrics) -> EmotionalState {

        let heartRate = metrics.heartRate
        let timestamp = metrics.timestamp
        let activity = metrics.activityState

        guard heartRate > 30, heartRate < 220 else {
            return currentState
        }

        guard activity == .stationary else {
            consecutiveElevatedSamples = 0
            currentState = .normal
            return currentState
        }

        guard let baselineHeartRate else {
            baselineSamples.append(heartRate)

            if baselineSamples.count >= baselineSampleCount {
                let sorted = baselineSamples.sorted()
                let baseline = sorted[sorted.count / 2]

                self.baselineHeartRate = baseline

                UserDefaults.standard.set(
                    baseline,
                    forKey: baselineHeartRateKey
                )

                currentState = .normal
            } else {
                currentState = .calibrating
            }

            return currentState
        }

        let threshold = max(
            baselineHeartRate + minimumElevation,
            baselineHeartRate * elevationPercentage
        )

        if heartRate >= threshold {

            consecutiveElevatedSamples += 1

            if consecutiveElevatedSamples >= requiredElevatedSamples {
                currentState = .potentialStress
            } else {
                currentState = .elevated
            }

        } else {

            consecutiveElevatedSamples = 0
            currentState = .normal
        }

        return currentState
    }
    // MARK: - Notification

    func shouldSendNotification() -> Bool {

        guard currentState == .potentialStress else {
            return false
        }

        let now = Date()

        if let lastNotificationDate,
           now.timeIntervalSince(lastNotificationDate) < notificationCooldown {
            return false
        }

        lastNotificationDate = now

        return true
    }

    // MARK: - Reset

    func reset() {

        baselineSamples.removeAll()

        baselineHeartRate = nil

        consecutiveElevatedSamples = 0

        lastSampleDate = nil

        lastNotificationDate = nil

        currentState = .calibrating

        UserDefaults.standard.removeObject(forKey: baselineSamplesKey)

        UserDefaults.standard.removeObject(forKey: baselineHeartRateKey)

        UserDefaults.standard.removeObject(
            forKey: "mindguard.lastNotificationDate"
        )
    }
}
