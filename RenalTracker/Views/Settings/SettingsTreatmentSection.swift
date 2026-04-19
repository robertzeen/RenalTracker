//
//  SettingsTreatmentSection.swift
//  RenalTracker
//

import SwiftUI

struct SettingsTreatmentSection: View {
    @Binding var selectedCategory: UserCategory
    @Binding var hemoStartDate: Date
    @Binding var hemoEndDate: Date
    @Binding var hemoOngoing: Bool
    @Binding var pdStartDate: Date
    @Binding var pdEndDate: Date
    @Binding var pdOngoing: Bool
    @Binding var transplantDate: Date
    @Binding var pendingCategory: UserCategory?
    @Binding var showChangeAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("СТАТУС ЛЕЧЕНИЯ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ForEach(UserCategory.allCases, id: \.self) { category in
                let isSelected = selectedCategory == category
                HStack(spacing: 12) {
                    Text(categoryIcon(category))
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(categoryTitle(category))
                            .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        if isSelected {
                            Text(categorySubtitle(category))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color(.separator),
                            lineWidth: isSelected ? 2 : 0.5))
                .onTapGesture {
                    if selectedCategory != category {
                        pendingCategory = category
                        showChangeAlert = true
                    }
                }
            }

            treatmentDateCard
        }
    }

    // MARK: - Date card

    @ViewBuilder
    private var treatmentDateCard: some View {
        VStack(spacing: 0) {
            switch selectedCategory {
            case .hemodialysis:
                dateCardRow(title: "ДАТА НАЧАЛА") {
                    DatePicker("", selection: $hemoStartDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
                Divider().padding(.leading, 14)
                toggleRow(title: "По настоящее время", isOn: $hemoOngoing)
                if !hemoOngoing {
                    Divider().padding(.leading, 14)
                    dateCardRow(title: "ДАТА ОКОНЧАНИЯ") {
                        DatePicker("", selection: $hemoEndDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }
                }

            case .peritonealDialysis:
                dateCardRow(title: "ДАТА НАЧАЛА") {
                    DatePicker("", selection: $pdStartDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
                Divider().padding(.leading, 14)
                toggleRow(title: "По настоящее время", isOn: $pdOngoing)
                if !pdOngoing {
                    Divider().padding(.leading, 14)
                    dateCardRow(title: "ДАТА ОКОНЧАНИЯ") {
                        DatePicker("", selection: $pdEndDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }
                }

            case .postTransplant:
                dateCardRow(title: "ДАТА ОПЕРАЦИИ") {
                    DatePicker("", selection: $transplantDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.separator), lineWidth: 0.5))
    }

    private func dateCardRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                content()
            }
            Spacer()
        }
        .padding(14)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(14)
    }

    // MARK: - Helpers

    private func categoryIcon(_ cat: UserCategory) -> String {
        switch cat {
        case .hemodialysis:       return "💉"
        case .peritonealDialysis: return "💧"
        case .postTransplant:     return "🌱"
        }
    }

    private func categoryTitle(_ cat: UserCategory) -> String {
        switch cat {
        case .hemodialysis:       return "Гемодиализ"
        case .peritonealDialysis: return "Перитонеальный диализ"
        case .postTransplant:     return "После трансплантации"
        }
    }

    private func categorySubtitle(_ cat: UserCategory) -> String {
        switch cat {
        case .hemodialysis:
            let end = hemoOngoing ? Date() : hemoEndDate
            if let days = durationDays(start: hemoStartDate, end: end) {
                return "День \(days) · c \(DateFormatter.russianDate.string(from: hemoStartDate))"
            }
            return "С \(DateFormatter.russianDate.string(from: hemoStartDate))"
        case .peritonealDialysis:
            let end = pdOngoing ? Date() : pdEndDate
            if let days = durationDays(start: pdStartDate, end: end) {
                return "День \(days) · c \(DateFormatter.russianDate.string(from: pdStartDate))"
            }
            return "С \(DateFormatter.russianDate.string(from: pdStartDate))"
        case .postTransplant:
            if let days = durationDays(start: transplantDate, end: Date()) {
                return "День \(days) после операции"
            }
            return DateFormatter.russianDate.string(from: transplantDate)
        }
    }

    private func durationDays(start: Date, end: Date) -> Int? {
        let components = Calendar.current.dateComponents([.day], from: start, to: end)
        guard let days = components.day, days >= 0 else { return nil }
        return days
    }
}
