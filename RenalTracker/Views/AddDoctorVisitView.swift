//
//  AddDoctorVisitView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct AddDoctorVisitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingVisit: DoctorVisit? = nil

    @State private var doctorName: String
    @State private var selectedDate: Date
    @State private var notes: String
    @State private var showDatePicker = false

    init(existingVisit: DoctorVisit? = nil) {
        self.existingVisit = existingVisit
        _doctorName = State(initialValue: existingVisit?.doctorName ?? "")
        _selectedDate = State(initialValue: existingVisit?.date ?? Date())
        _notes = State(initialValue: existingVisit?.notes ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {

                    // 1. Карточка врача
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Text("👩‍⚕️")
                                .font(.title3)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ВРАЧ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("ФИО врача (опционально)", text: $doctorName)
                                .font(.system(size: 15, weight: .medium))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    // 2. Карточка даты
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ДАТА ПРИЁМА")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(formattedDateTime)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                            Spacer()
                            Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                        .onTapGesture { showDatePicker.toggle() }

                        if showDatePicker {
                            Divider()
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .padding(.horizontal, 8)
                            .onChange(of: selectedDate) { _, _ in
                                showDatePicker = false
                            }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    // 3. Карточка заметок
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ЗАМЕТКИ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField(
                            "Рекомендации врача, изменения в лечении, результаты осмотра, вопросы на следующий приём...",
                            text: $notes,
                            axis: .vertical
                        )
                        .font(.system(size: 15))
                        .lineLimit(5...)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))
                }
                .padding(16)
            }
            .navigationTitle(existingVisit == nil ? "Новая запись" : "Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                        dismiss()
                    }
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
        }
    }

    // MARK: - Вычисляемые свойства

    var formattedDateTime: String {
        DateFormatter.russianDateTime.string(from: selectedDate)
    }

    // MARK: - Действия

    func save() {
        if let visit = existingVisit {
            visit.doctorName = doctorName.isEmpty ? nil : doctorName
            visit.date = selectedDate
            visit.notes = notes.isEmpty ? nil : notes
        } else {
            let visit = DoctorVisit(
                date: selectedDate,
                doctorName: doctorName.isEmpty ? nil : doctorName,
                notes: notes.isEmpty ? nil : notes
            )
            modelContext.insert(visit)
        }
        try? modelContext.save()
    }
}
