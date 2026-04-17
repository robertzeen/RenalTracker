//
//  ContentView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if profiles.contains(where: { $0.hasCompletedOnboarding }) {
                MainTabView()
            } else {
                OnboardingView(onComplete: { })
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            UserProfile.self,
            BloodPressure.self,
            Weight.self,
            LabResult.self,
            Medication.self,
            WellBeing.self,
            DoctorVisit.self
        ], inMemory: true)
}
