//
//  MindGuardApp.swift
//  MindGuard
//
//  Created by Luthfi Asmara on 12/11/26.
//

import SwiftUI

@main
struct MindGuardApp: App {

    @StateObject private var healthKitManager =
        HealthKitManager.shared

    var body: some Scene {

        WindowGroup {

            DashboardView()
                .environmentObject(healthKitManager)
                .task {
                    await healthKitManager.start()
                }
        }
    }
}
