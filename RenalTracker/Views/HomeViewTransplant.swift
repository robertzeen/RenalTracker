//
//  HomeViewTransplant.swift
//  RenalTracker
//
//  Главный экран для пациентов после трансплантации.
//

import SwiftUI
import SwiftData
import EventKit

struct HomeViewTransplant: View {
    var onShowMedications: (() -> Void)?
    var onShowDoctorVisits: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    @State private var isShowingDoctorDateSheet = false
    @State private var isShowingLabTestDateSheet = false
    @State private var isShowingSettings = false

    @State private var currentTime = Date()
    @State private var refreshTimer: Timer?
    
    @State private var isShowingWellbeingTest = false

    @Query private var profiles: [UserProfile]
    @Query(sort: \BloodPressure.date, order: .reverse) private var bloodPressureRecords: [BloodPressure]
    @Query(sort: \Weight.date, order: .reverse) private var weightRecords: [Weight]
    @Query(sort: \Medication.name, order: .forward) private var medications: [Medication]
    @Query(sort: \MedicationIntake.date, order: .forward) private var intakes: [MedicationIntake]

    // MARK: - Profile

    private var currentProfile: UserProfile? { profiles.first }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        default: return "Добрый вечер"
        }
    }

    private var statusText: String? {
        guard let profile = currentProfile else { return nil }
        switch profile.category {
        case .postTransplant:
            if let date = profile.transplantDate, let days = daysSince(date) {
                return "🌱 День \(days) после трансплантации"
            }
        case .hemodialysis:
            if let date = profile.hemoStartDate, let days = daysSince(date) {
                return "💉 День \(days) на гемодиализе"
            }
        case .peritonealDialysis:
            if let date = profile.pdStartDate, let days = daysSince(date) {
                return "💧 День \(days) на перитонеальном диализе"
            }
        }
        return nil
    }

    private var displayName: String {
        if let profile = currentProfile, !profile.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return profile.name
        }
        return "друг"
    }

    // MARK: - Medications schedule

    private var scheduleCalculator: MedicationScheduleCalculator {
        MedicationScheduleCalculator(medications: medications, intakes: intakes, now: currentTime)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HomeGreetingView(
                        greeting: greetingText,
                        displayName: displayName,
                        statusText: statusText
                    )
                    .padding(.vertical, 4)

                    HomeMetricsView(
                        latestBloodPressure: bloodPressureRecords.first,
                        latestWeight: weightRecords.first
                    )
                    .padding(.vertical, 4)

                    HomeMedicationsView(
                        hasMedications: !medications.isEmpty,
                        groups: scheduleCalculator.todayScheduleGroups,
                        allTaken: scheduleCalculator.allTaken,
                        nextUpcomingGroup: scheduleCalculator.nextUpcomingGroup,
                        isTaken: { scheduleCalculator.isTaken($0) }
                    )
                    .padding(.vertical, 4)

                    HomeEventsView(
                        profile: currentProfile,
                        currentTime: currentTime,
                        onShowDoctorVisits: onShowDoctorVisits,
                        isShowingDoctorDateSheet: $isShowingDoctorDateSheet,
                        isShowingLabTestDateSheet: $isShowingLabTestDateSheet
                    )
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isShowingSettings = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 32, height: 32)
                            Image(systemName: "gearshape")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Настройки")
                }
            }
        }
        .sheet(isPresented: $isShowingDoctorDateSheet) {
            DoctorAppointmentSheet(userProfile: currentProfile)
        }
        .sheet(isPresented: $isShowingLabTestDateSheet) {
            LabTestSheet(userProfile: currentProfile)
        }
        .sheet(isPresented: $isShowingSettings) {
            if let profile = currentProfile {
                SettingsView(profile: profile, onDismiss: { isShowingSettings = false })
            }
        }
        .onAppear {
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
            NotificationManager.shared.printScheduledNotifications()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Helpers

    private func daysSince(_ date: Date) -> Int? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        let components = Calendar.current.dateComponents([.day], from: startOfDay, to: today)
        guard let days = components.day, days >= 0 else { return nil }
        return days + 1
    }
}

#Preview {
    HomeViewTransplant()
        .modelContainer(for: [UserProfile.self, BloodPressure.self, Weight.self, Medication.self, MedicationIntake.self], inMemory: true)
}
