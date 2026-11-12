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

    @Published private(set) var latestHeartRate: Double = 0

    @Published private(set) var connectionStatus = "Disconnected"

    @Published private(set) var emotionalState: EmotionalState = .calibrating

    private let engine = EmotionalEngine.shared

    private override init() {
        super.init()

        activateSession()
    }

    private func activateSession() {

        guard WCSession.isSupported() else {
            return
        }

        let session = WCSession.default

        session.delegate = self

        session.activate()
    }

    private func handleHeartRate(_ data: [String: Any]) {

        guard
            let heartRate = data["heartRate"] as? Double,
            let timestamp = data["timestamp"] as? Double
        else {
            return
        }

        let metrics = EmotionalMetrics(
            heartRate: heartRate,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )

        DispatchQueue.main.async {

            self.latestHeartRate = heartRate

            let state = self.engine.process(metrics)

            self.emotionalState = state

            if self.engine.shouldSendNotification() {

                NotificationManager.shared.sendMindfulnessNotification()
            }
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {

        DispatchQueue.main.async {

            self.connectionStatus = activationState == .activated
                ? "Connected"
                : "Disconnected"
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {

        session.activate()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {

        handleHeartRate(message)
    }

    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {

        handleHeartRate(userInfo)
    }
}