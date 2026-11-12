//
//  WatchConnectivitySender.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//


import Foundation
import WatchConnectivity

final class WatchConnectivitySender: NSObject {

    static let shared = WatchConnectivitySender()

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

    func sendHeartRate(_ heartRate: Double) {

        let data: [String: Any] = [
            "heartRate": heartRate,
            "timestamp": Date().timeIntervalSince1970
        ]

        let session = WCSession.default

        guard session.activationState == .activated else {
            return
        }

        if session.isReachable {

            session.sendMessage(
                data,
                replyHandler: nil,
                errorHandler: { error in
                    print("Send message error:", error)
                }
            )

        } else {

            session.transferUserInfo(data)
        }
    }
}

extension WatchConnectivitySender: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionReachabilityDidChange(_ session: WCSession) {}
}