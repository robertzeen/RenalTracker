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
        _selectedCategory = State(initialValue: profile.category)
        _hemoStartDate = State(initialValue: profile.hemoStartDate ?? Date())
        _hemoEndDate = State(initialValue: profile.hemoEndDate ?? Date())
        _hemoOngoing = State(initialValue: profile.hemoOngoing)
        _pdStartDate = State(initialValue: profile.pdStartDate ?? Date())
        _pdEndDate = State(initialValue: profile.pdEndDate ?? Date())
        _pdOngoing = State(initialValue: profile.pdOngoing)
        _transplantDate = State(initialValue: profile.transplantDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                statusSection
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        saveAndDismiss()
                    }
                }
            }
            .alert("Изменить статус лечения?", isPresented: $showChangeAlert) {
                Button("Отмена", role: .cancel) {
                    pendingCategory = nil
                }
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

    private var statusSection: some View {
        Section {
            VStack(spacing: 12) {
                statusCard(icon: "💉", title: "Гемодиализ", category: .hemodialysis)
                statusCard(icon: "💧", title: "Перитонеальный диализ", category: .peritonealDialysis)
                statusCard(icon: "🌱", title: "После трансплантации почки", category: .postTransplant)
            }
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                switch selectedCategory {
                case .hemodialysis:
                    dialysisDateFields(
                        startDate: $hemoStartDate,
                        endDate: $hemoEndDate,
                        ongoing: $hemoOngoing,
                        titleStart: "Дата начала",
                        titleEnd: "Дата окончания"
                    )
                    if let days = durationDays(start: hemoStartDate, end: hemoOngoing ? Date() : hemoEndDate) {
                        Text("Продолжительность: \(days) дней")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .peritonealDialysis:
                    dialysisDateFields(
                        startDate: $pdStartDate,
                        endDate: $pdEndDate,
                        ongoing: $pdOngoing,
                        titleStart: "Дата начала",
                        titleEnd: "Дата окончания"
                    )
                    if let days = durationDays(start: pdStartDate, end: pdOngoing ? Date() : pdEndDate) {
                        Text("Продолжительность: \(days) дней")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .postTransplant:
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Дата операции")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker("Дата операции", selection: $transplantDate, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                        }
                        if let days = durationDays(start: transplantDate, end: Date()) {
                            Text("Дней со дня операции: \(days)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text("СТАТУС ЛЕЧЕНИЯ")
        }
    }

    private func statusCard(icon: String, title: String, category: UserCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            if category == selectedCategory { return }
            pendingCategory = category
            showChangeAlert = true
        } label: {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dialysisDateFields(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        ongoing: Binding<Bool>,
        titleStart: String,
        titleEnd: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleStart)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker(titleStart, selection: startDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ru_RU"))
            }
            Toggle("По настоящее время", isOn: ongoing)
            if !ongoing.wrappedValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleEnd)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(titleEnd, selection: endDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
        }
    }

    private func durationDays(start: Date, end: Date) -> Int? {
        let components = Calendar.current.dateComponents([.day], from: start, to: end)
        guard let days = components.day, days >= 0 else { return nil }
        return days
    }

    private func resetDatesForCategory(_ category: UserCategory) {
        switch category {
        case .hemodialysis:
            hemoStartDate = Date()
            hemoEndDate = Date()
            hemoOngoing = true
        case .peritonealDialysis:
            pdStartDate = Date()
            pdEndDate = Date()
            pdOngoing = true
        case .postTransplant:
            transplantDate = Date()
        }
    }

    private func saveAndDismiss() {
        profile.category = selectedCategory

        switch selectedCategory {
        case .hemodialysis:
            profile.hemoStartDate = hemoStartDate
            profile.hemoEndDate = hemoOngoing ? nil : hemoEndDate
            profile.hemoOngoing = hemoOngoing
            profile.pdStartDate = nil
            profile.pdEndDate = nil
            profile.pdOngoing = false
            profile.transplantDate = nil
        case .peritonealDialysis:
            profile.pdStartDate = pdStartDate
            profile.pdEndDate = pdOngoing ? nil : pdEndDate
            profile.pdOngoing = pdOngoing
            profile.hemoStartDate = nil
            profile.hemoEndDate = nil
            profile.hemoOngoing = false
            profile.transplantDate = nil
        case .postTransplant:
            profile.transplantDate = transplantDate
            profile.hemoStartDate = nil
            profile.hemoEndDate = nil
            profile.hemoOngoing = false
            profile.pdStartDate = nil
            profile.pdEndDate = nil
            profile.pdOngoing = false
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
