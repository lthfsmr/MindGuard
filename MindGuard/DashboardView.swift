//
//  DashboardView.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//


import SwiftUI

struct DashboardView: View {

    @EnvironmentObject var healthKitManager: HealthKitManager

    var body: some View {

        NavigationStack {

            VStack(spacing: 24) {

                Text("MindGuard")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                VStack(spacing: 8) {

                    Text("Latest Heart Rate")
                        .font(.headline)

                    Text(
                        healthKitManager.latestHeartRate > 0
                        ? "\(Int(healthKitManager.latestHeartRate)) BPM"
                        : "-- BPM"
                    )
                    .font(.system(size: 48, weight: .bold))

                    if let date = healthKitManager.latestSampleDate {

                        Text("Updated: \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 8) {

                    Text("Physiological State")
                        .font(.headline)

                    Text(stateDescription)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(stateColor)
                }

                if let error = healthKitManager.errorMessage {

                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Spacer()
            }
            .padding()
        }
    }

    private var stateDescription: String {

        switch healthKitManager.emotionalState {

        case .calibrating:
            return "Calibrating..."

        case .normal:
            return "Normal 🌿"

        case .elevated:
            return "Elevated Heart Rate"

        case .potentialStress:
            return "Take a Breath"
        }
    }

    private var stateColor: Color {

        switch healthKitManager.emotionalState {

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
