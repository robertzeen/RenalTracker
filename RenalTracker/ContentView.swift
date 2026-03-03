//
//  ContentView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var hasCompletedOnboarding: Bool = false

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(onComplete: { hasCompletedOnboarding = true })
            } else {
                MainTabView()
            }
        }
        .onAppear {
            hasCompletedOnboarding = profiles.contains { $0.hasCompletedOnboarding }
        }
        .onChange(of: profiles.count) { _, _ in
            hasCompletedOnboarding = profiles.contains { $0.hasCompletedOnboarding }
        }
    }

    private var showOnboarding: Bool {
        !hasCompletedOnboarding
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
            WellBeing.self
        ], inMemory: true)
}
