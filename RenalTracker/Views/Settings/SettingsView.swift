//
//  SettingsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    var profile: UserProfile
    var onDismiss: () -> Void

    // MARK: - Личные данные
    @State private var firstName: String
    @State private var lastName: String

    // MARK: - Статус лечения
    @State private var selectedCategory: UserCategory
    @State private var showChangeAlert = false
    @State private var pendingCategory: UserCategory?

    @State private var hemoStartDate: Date
    @State private var hemoEndDate: Date
    @State private var hemoOngoing: Bool
    @State private var pdStartDate: Date
    @State private var pdEndDate: Date
    @State private var pdOngoing: Bool
    @State private var transplantDate: Date

    init(profile: UserProfile, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.onDismiss = onDismiss
        _firstName        = State(initialValue: profile.name)
        _lastName         = State(initialValue: profile.lastName ?? "")
        _selectedCategory = State(initialValue: profile.category)
        _hemoStartDate    = State(initialValue: profile.hemoStartDate ?? Date())
        _hemoEndDate      = State(initialValue: profile.hemoEndDate ?? Date())
        _hemoOngoing      = State(initialValue: profile.hemoOngoing)
        _pdStartDate      = State(initialValue: profile.pdStartDate ?? Date())
        _pdEndDate        = State(initialValue: profile.pdEndDate ?? Date())
        _pdOngoing        = State(initialValue: profile.pdOngoing)
        _transplantDate   = State(initialValue: profile.transplantDate ?? Date())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SettingsPersonalSection(
                        firstName: $firstName,
                        lastName: $lastName
                    )
                    SettingsTreatmentSection(
                        selectedCategory: $selectedCategory,
                        hemoStartDate: $hemoStartDate,
                        hemoEndDate: $hemoEndDate,
                        hemoOngoing: $hemoOngoing,
                        pdStartDate: $pdStartDate,
                        pdEndDate: $pdEndDate,
                        pdOngoing: $pdOngoing,
                        transplantDate: $transplantDate,
                        pendingCategory: $pendingCategory,
                        showChangeAlert: $showChangeAlert
                    )
                    SettingsNotificationsSection()
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveAndDismiss() }
                        .fontWeight(.medium)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
            .alert("Изменить статус лечения?", isPresented: $showChangeAlert) {
                Button("Отмена", role: .cancel) { pendingCategory = nil }
                Button("Изменить") {
                    if let newCategory = pendingCategory {
                        selectedCategory = newCategory
                        resetDatesForCategory(newCategory)
                    }
                    pendingCategory = nil
                }
            } message: {
                Text("Отсчёт дней на главном экране будет пересчитан с новой даты.")
            }
        }
    }

    // MARK: - Helpers

    private func resetDatesForCategory(_ category: UserCategory) {
        switch category {
        case .hemodialysis:
            hemoStartDate = Date(); hemoEndDate = Date(); hemoOngoing = true
        case .peritonealDialysis:
            pdStartDate = Date(); pdEndDate = Date(); pdOngoing = true
        case .postTransplant:
            transplantDate = Date()
        }
    }

    // MARK: - Сохранение

    private func saveAndDismiss() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast  = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name     = trimmedFirst.isEmpty ? "друг" : trimmedFirst
        profile.lastName = trimmedLast.isEmpty ? nil : trimmedLast
        profile.category = selectedCategory

        switch selectedCategory {
        case .hemodialysis:
            profile.hemoStartDate = hemoStartDate
            profile.hemoEndDate   = hemoOngoing ? nil : hemoEndDate
            profile.hemoOngoing   = hemoOngoing
            profile.pdStartDate   = nil; profile.pdEndDate = nil; profile.pdOngoing = false
            profile.transplantDate = nil
        case .peritonealDialysis:
            profile.pdStartDate   = pdStartDate
            profile.pdEndDate     = pdOngoing ? nil : pdEndDate
            profile.pdOngoing     = pdOngoing
            profile.hemoStartDate = nil; profile.hemoEndDate = nil; profile.hemoOngoing = false
            profile.transplantDate = nil
        case .postTransplant:
            profile.transplantDate = transplantDate
            profile.hemoStartDate  = nil; profile.hemoEndDate = nil; profile.hemoOngoing = false
            profile.pdStartDate    = nil; profile.pdEndDate = nil; profile.pdOngoing = false
        }

        try? modelContext.save()
        onDismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)
    let profile = UserProfile(category: .hemodialysis, name: "Иван", hasCompletedOnboarding: true)
    container.mainContext.insert(profile)
    return SettingsView(profile: profile, onDismiss: {})
        .modelContainer(container)
}
