//
//  AllMedicationsView.swift
//  RenalTracker
//
//  Полный список всех принимаемых лекарств — для редактирования
//  и удаления вне контекста "сегодня".
//

import SwiftUI
import SwiftData

struct AllMedicationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Medication.name) private var medications: [Medication]

    @AppStorage(AppStorageKeys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(AppStorageKeys.criticalNotificationsEnabled) private var criticalNotificationsEnabled = false

    @State private var medicationToEdit: Medication?
    @State private var medicationToDelete: Medication?
    @State private var isShowingDeleteConfirmation = false

    private var sortedMedications: [Medication] {
        medications.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            Group {
                if medications.isEmpty {
                    EmptyStatePlaceholder(
                        emoji: "💊",
                        title: "Нет лекарств",
                        description: "Добавьте принимаемые лекарства\nна главном экране расписания",
                        buttonTitle: "Закрыть",
                        action: { dismiss() }
                    )
                } else {
                    List {
                        ForEach(sortedMedications) { med in
                            Button {
                                medicationToEdit = med
                            } label: {
                                medicationRow(med: med)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color(.secondarySystemBackground))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    medicationToDelete = med
                                    isShowingDeleteConfirmation = true
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }
                                Button {
                                    medicationToEdit = med
                                } label: {
                                    Label("Изменить", systemImage: "pencil")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Все лекарства")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(item: $medicationToEdit) { med in
            EditMedicationSheet(medication: med)
        }
        .alert("Удалить лекарство?",
               isPresented: $isShowingDeleteConfirmation,
               presenting: medicationToDelete) { med in
            Button("Удалить", role: .destructive) {
                modelContext.delete(med)
                try? modelContext.save()
                NotificationManager.shared.rescheduleMedicationNotifications(
                    for: medications.filter { $0.id != med.id },
                    enabled: notificationsEnabled,
                    critical: criticalNotificationsEnabled
                )
                medicationToDelete = nil
            }
            Button("Отмена", role: .cancel) {
                medicationToDelete = nil
            }
        } message: { med in
            Text("\(med.name) будет удалён вместе со всей историей приёмов.")
        }
    }

    @ViewBuilder
    private func medicationRow(med: Medication) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(med.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if !med.formattedDosage.isEmpty {
                        Text(med.formattedDosage)
                    }
                    Text("·")
                    Text(DateFormatter.russianTime.string(from: med.time))
                    Text("·")
                    Text(weekdaysDescription(for: med))
                }
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func weekdaysDescription(for med: Medication) -> String {
        if med.daysOfWeek.count == 7 {
            return "каждый день"
        }
        let weekdayNames = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]
        let sorted = med.daysOfWeek.sorted()
        return sorted.map { weekdayNames[$0 - 1] }.joined(separator: ", ")
    }
}
