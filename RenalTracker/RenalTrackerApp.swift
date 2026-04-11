//
//  RenalTrackerApp.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct RenalTrackerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema(CurrentSchema.models)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    let center = UNUserNotificationCenter.current()
                    let granted = try? await center.requestAuthorization(
                        options: [.alert, .sound, .badge]
                    )
                    if let granted {
                        print("[Notifications] Authorization granted: \(granted)")
                    } else {
                        print("[Notifications] Authorization request failed")
                    }
                    await MainActor.run {
                        center.setBadgeCount(0) { error in
                            if let error {
                                print("[Notifications] setBadgeCount error: \(error)")
                            }
                        }
                    }
                    if granted == true {
                        await MainActor.run {
                            NotificationManager.shared.updateNotifications()
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
