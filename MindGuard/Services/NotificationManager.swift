//
//  NotificationManager.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//


import Foundation
import UserNotifications

final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    func requestPermission() async -> Bool {

        do {

            return try await UNUserNotificationCenter.current()
                .requestAuthorization(
                    options: [.alert, .sound, .badge]
                )

        } catch {

            print("Notification permission error:", error)

            return false
        }
    }

    func sendMindfulnessNotification() {

        let content = UNMutableNotificationContent()

        content.title = "Take a Breath 🌿"

        content.body = """
        Your body may be responding to increased arousal.
        Take a moment to pause and breathe.
        """

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "mindguard.potential-stress",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in

            if let error {
                print("Notification error:", error)
            }
        }
    }
}