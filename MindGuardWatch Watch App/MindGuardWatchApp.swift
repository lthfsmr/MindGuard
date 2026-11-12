//
//  MindGuardWatchApp.swift
//  MindGuardWatch Watch App
//
//  Created by Luthfi Asmara on 12/11/26.
//

import SwiftUI

@main
struct MindGuardWatchApp: App {

    var body: some Scene {

        WindowGroup {

            WatchMonitoringView()
        }
    }
}

struct WatchMonitoringView: View {

    @StateObject private var monitor = HeartRateMonitor()

    var body: some View {

        VStack(spacing: 12) {

            Text("MindGuard")
                .font(.headline)

            Text(
                monitor.heartRate > 0
                ? "\(Int(monitor.heartRate)) BPM"
                : "-- BPM"
            )
            .font(.system(size: 30, weight: .bold))

            Button(
                monitor.isMonitoring
                ? "Stop Monitoring"
                : "Start Monitoring"
            ) {

                if monitor.isMonitoring {

                    monitor.stopMonitoring()

                } else {

                    monitor.startMonitoring()
                }
            }
            .tint(monitor.isMonitoring ? .red : .green)
        }
        .task {

            do {

                try await monitor.requestAuthorization()

            } catch {

                print("HealthKit authorization error:", error)
            }
        }
    }
}

