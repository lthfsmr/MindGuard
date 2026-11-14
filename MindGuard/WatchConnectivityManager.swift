//
//  WatchConnectivityManager.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//


import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    // MARK: - Published Properties

    @Published private(set) var latestHeartRate: Double = 0

    @Published private(set) var latestSampleDate: Date?

    @Published private(set) var latestActivityState: ActivityState = .unknown

    @Published private(set) var connectionStatus = "Disconnected"

    @Published private(set) var emotionalState: EmotionalState = .calibrating

    // MARK: - Properties

    private let engine = EmotionalEngine.shared

    private override init() {
        super.init()
        activateSession()
    }

    // MARK: - Session

    private func activateSession() {

        guard WCSession.isSupported() else {
            connectionStatus = "Not Supported"
            return
        }

        let session = WCSession.default

        session.delegate = self
        session.activate()
    }

    // MARK: - Handle Incoming Data

    private func handleHeartRate(_ data: [String: Any]) {

        guard
            let heartRate = data["heartRate"] as? Double,
            let timestamp = data["timestamp"] as? Double
        else {
            print("Invalid heart rate payload:", data)
            return
        }

        let activityRawValue = data["activityState"] as? String ?? "unknown"

        let activityState = ActivityState(
            rawValue: activityRawValue
        ) ?? .unknown

        let metrics = EmotionalMetrics(
            heartRate: heartRate,
            timestamp: Date(timeIntervalSince1970: timestamp),
            activityState: activityState
        )

        DispatchQueue.main.async {

            self.latestHeartRate = heartRate

            self.latestSampleDate = metrics.timestamp

            self.latestActivityState = activityState

            let state = self.engine.process(metrics)

            self.emotionalState = state

            print("""
            MindGuard Received:
            HR: \(heartRate)
            Activity: \(activityState.rawValue)
            State: \(state)
            """)

            guard state == .potentialStress else {
                return
            }

            if self.engine.shouldSendNotification() {
                NotificationManager.shared.sendMindfulnessNotification()
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {

        DispatchQueue.main.async {

            if let error {
                self.connectionStatus = "Error"
                print("WatchConnectivity activation error:", error)
                return
            }

            self.connectionStatus = activationState == .activated
                ? "Connected"
                : "Disconnected"
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchConnectivity session became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {

        print("WatchConnectivity session deactivated")

        session.activate()
    }

    // MARK: - Real-time Message

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {

        handleHeartRate(message)
    }

    // MARK: - Background Transfer

    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {

        handleHeartRate(userInfo)
    }

    // MARK: - Reachability

    func sessionReachabilityDidChange(_ session: WCSession) {

        DispatchQueue.main.async {

            self.connectionStatus = session.isReachable
                ? "Connected"
                : "Not Reachable"
        }
    }
}
