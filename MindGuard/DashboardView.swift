//
//  DashboardView.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//


import SwiftUI

struct DashboardView: View {

    @EnvironmentObject var connectivity: WatchConnectivityManager

    var body: some View {

        NavigationStack {

            VStack(spacing: 24) {

                VStack(spacing: 8) {

                    Text("MindGuard")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your mindful companion")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {

                    Text("Heart Rate")
                        .font(.headline)

                    Text(
                        connectivity.latestHeartRate > 0
                        ? "\(Int(connectivity.latestHeartRate)) BPM"
                        : "-- BPM"
                    )
                    .font(.system(size: 48, weight: .bold))
                }

                VStack(spacing: 8) {

                    Text("Current State")
                        .font(.headline)

                    Text(stateDescription)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(stateColor)
                }

                HStack {

                    Circle()
                        .fill(
                            connectivity.connectionStatus == "Connected"
                            ? .green
                            : .red
                        )
                        .frame(width: 10, height: 10)

                    Text("Apple Watch: \(connectivity.connectionStatus)")
                        .font(.subheadline)
                }

                Button("Enable Notifications") {

                    Task {
                        let granted = await NotificationManager.shared
                            .requestPermission()

                        print("Notification permission:", granted)
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }

    private var stateDescription: String {

        switch connectivity.emotionalState {

        case .calibrating:
            return "Calibrating baseline..."

        case .normal:
            return "You're doing well 🌿"

        case .elevated:
            return "Elevated heart rate"

        case .potentialStress:
            return "Take a moment to breathe"

        }
    }

    private var stateColor: Color {

        switch connectivity.emotionalState {

        case .calibrating:
            return .gray

        case .normal:
            return .green

        case .elevated:
            return .orange

        case .potentialStress:
            return .red
        }
    }
}