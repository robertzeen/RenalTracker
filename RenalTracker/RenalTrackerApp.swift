//
//  RenalTrackerApp.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

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
        }
        .modelContainer(sharedModelContainer)
    }
}
