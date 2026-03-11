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
        let schema = Schema([
            UserProfile.self,
            BloodPressure.self,
            Weight.self,
            LabResult.self,
            Medication.self,
            MedicationIntake.self,
            WellBeing.self,
            TrackedLabTest.self,
            DoctorVisit.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    UNUserNotificationCenter.current().requestAuthorization(
                        options: [.alert, .sound, .badge]
                    ) { granted, error in
                        if let error {
                            print("[Notifications] requestAuthorization error: \(error)")
                        }
                        print("[Notifications] Authorization granted: \(granted)")
                    }
                    UNUserNotificationCenter.current().setBadgeCount(0) { error in
                        if let error {
                            print("[Notifications] setBadgeCount error: \(error)")
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
