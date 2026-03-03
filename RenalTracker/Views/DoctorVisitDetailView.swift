//
//  DoctorVisitDetailView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct DoctorVisitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var visit: DoctorVisit

    let isNewVisit: Bool

    @State private var date: Date
    @State private var doctorNameText: String
    @State private var notesText: String

    init(visit: DoctorVisit, isNewVisit: Bool) {
        self.visit = visit
        self.isNewVisit = isNewVisit
        _date = State(initialValue: visit.date)
        _doctorNameText = State(initialValue: visit.doctorName ?? "")
        _notesText = State(initialValue: visit.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Дата и время") {
                    DatePicker(
                        "Дата и время",
                        selection: $date,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Section("Врач") {
                    TextField(
                        "ФИО врача (опционально)",
                        text: $doctorNameText
                    )
                    .textInputAutocapitalization(.words)
                }

                Section("Заметки") {
                    ZStack(alignment: .topLeading) {
                        if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Запишите рекомендации врача, изменения в лечении...")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $notesText)
                            .frame(minHeight: 150)
                            .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle(isNewVisit ? "Новый приём" : "Приём у врача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                        dismiss()
                    }
                }
            }
        }
    }

    private func cancel() {
        if isNewVisit {
            // Отмена создания нового приёма — удаляем запись
            modelContext.delete(visit)
            try? modelContext.save()
        }
        dismiss()
    }

    private func save() {
        visit.date = date

        let trimmedName = doctorNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.doctorName = trimmedName.isEmpty ? nil : trimmedName

        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        try? modelContext.save()
    }
}

