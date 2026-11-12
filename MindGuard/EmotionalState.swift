//
//  EmotionalState.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//


import Foundation

enum EmotionalState {
    case calibrating
    case normal
    case elevated
    case potentialStress
}

final class EmotionalEngine {

    static let shared = EmotionalEngine()

    private init() {}

    private var baselineSamples: [Double] = []

    private var baselineHeartRate: Double?

    private var elevatedStartDate: Date?

    private var lastSampleDate: Date?

    private var lastNotificationDate: Date?

    private let baselineSampleCount = 20

    private let minimumElevation: Double = 15

    private let elevationPercentage: Double = 1.20

    private let requiredElevationDuration: TimeInterval = 60

    private let notificationCooldown: TimeInterval = 1800

    private let maximumSampleGap: TimeInterval = 180

    private(set) var currentState: EmotionalState = .calibrating

    func process(_ metrics: EmotionalMetrics) -> EmotionalState {

        let heartRate = metrics.heartRate
        let timestamp = metrics.timestamp

        guard heartRate > 30, heartRate < 220 else {
            return currentState
        }

        // Ignore old or duplicated samples.
        if let lastSampleDate,
           timestamp <= lastSampleDate {
            return currentState
        }

        // Reset elevated tracking if there is a long data gap.
        if let lastSampleDate,
           timestamp.timeIntervalSince(lastSampleDate) > maximumSampleGap {
            elevatedStartDate = nil
        }

        lastSampleDate = timestamp

        // Build initial baseline.
        guard let baselineHeartRate else {

            baselineSamples.append(heartRate)

            if baselineSamples.count >= baselineSampleCount {

                let sortedSamples = baselineSamples.sorted()

                let middleIndex = sortedSamples.count / 2

                self.baselineHeartRate = sortedSamples[middleIndex]

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

            if elevatedStartDate == nil {
                elevatedStartDate = timestamp
            }

            guard let elevatedStartDate else {
                return currentState
            }

            let duration = timestamp.timeIntervalSince(elevatedStartDate)

            if duration >= requiredElevationDuration {
                currentState = .potentialStress
            } else {
                currentState = .elevated
            }

        } else {

            elevatedStartDate = nil
            currentState = .normal
        }

        return currentState
    }

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

    func reset() {

        baselineSamples.removeAll()

        baselineHeartRate = nil

        elevatedStartDate = nil

        lastSampleDate = nil

        lastNotificationDate = nil

        currentState = .calibrating
    }

    var currentBaseline: Double? {
        baselineHeartRate
    }
}