//
//  HomeView.swift
//  RenalTracker
//
//  Диспетчер: выбирает специализированный главный экран
//  в зависимости от категории пациента.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Query private var profiles: [UserProfile]

    var onShowMedications: (() -> Void)?
    var onShowDoctorVisits: (() -> Void)?

    init(
        onShowMedications: (() -> Void)? = nil,
        onShowDoctorVisits: (() -> Void)? = nil
    ) {
        self.onShowMedications = onShowMedications
        self.onShowDoctorVisits = onShowDoctorVisits
    }

    var body: some View {
        Group {
            switch profiles.first?.category {
            case .postTransplant:
                HomeViewTransplant(
                    onShowMedications: onShowMedications,
                    onShowDoctorVisits: onShowDoctorVisits
                )
            case .hemodialysis:
                HomeViewHemo(
                    onShowMedications: onShowMedications,
                    onShowDoctorVisits: onShowDoctorVisits
                )
            case .peritonealDialysis:
                HomeViewPD(
                    onShowMedications: onShowMedications,
                    onShowDoctorVisits: onShowDoctorVisits
                )
            case nil:
                // Профиль ещё не создан (onboarding не пройден)
                ProgressView()
            }
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [UserProfile.self, BloodPressure.self, Weight.self, Medication.self, MedicationIntake.self], inMemory: true)
}
