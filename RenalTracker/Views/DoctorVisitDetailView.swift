//
//  DoctorVisitDetailView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import EventKit

struct DoctorVisitDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var visit: DoctorVisit

    let isNewVisit: Bool

    @State private var selectedDate: Date
    @State private var doctorNameText: String
    @State private var notesText: String
    @State private var showCalendarSuccess = false
    @State private var showDatePicker = false
    @State private var showTimePicker = false

    init(visit: DoctorVisit, isNewVisit: Bool) {
        self.visit = visit
        self.isNewVisit = isNewVisit
        _selectedDate = State(initialValue: visit.date)
        _doctorNameText = State(initialValue: visit.doctorName ?? "")
        _notesText = State(initialValue: visit.notes ?? "")
    }

    // MARK: - Вычисляемые свойства

    var formattedDate: String {
        DateFormatter.russianDate.string(from: selectedDate)
    }

    var formattedTime: String {
        DateFormatter.russianTime.string(from: selectedDate)
    }

    var daysUntil: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: selectedDate)
        ).day ?? 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    doctorCard
                    dateTimeCard
                    calendarButton
                    notesCard
                }
                .padding(16)
            }
            .navigationTitle(isNewVisit ? "Новый приём" : "Приём у врача")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Добавлено в календарь", isPresented: $showCalendarSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Событие добавлено в ваш календарь iPhone")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }

    // MARK: - Карточки

    private var doctorCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Text("👩‍⚕️")
                    .font(.title2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("ВРАЧ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("ФИО врача (опционально)", text: $doctorNameText)
                    .font(.system(size: 15, weight: .medium))
                    .textInputAutocapitalization(.words)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var dateTimeCard: some View {
        VStack(spacing: 0) {
            // Строка даты
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ДАТА")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedDate)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                }
                Spacer()
                if daysUntil > 0 {
                    Text("Через \(daysUntil) дней")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                } else if daysUntil == 0 {
                    Text("Сегодня")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(20)
                }
                Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { showDatePicker.toggle() }

            if showDatePicker {
                Divider()
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .padding(.horizontal, 8)
                    .onChange(of: selectedDate) { _, _ in
                        showDatePicker = false
                    }
            }

            Divider()

            // Строка времени
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ВРЕМЯ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedTime)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: showTimePicker ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { showTimePicker.toggle() }

            if showTimePicker {
                Divider()
                DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    private var calendarButton: some View {
        Button { addToCalendar() } label: {
            Label("Добавить в календарь", systemImage: "calendar.badge.plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ЗАМЕТКИ")
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                if notesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Запишите рекомендации врача, изменения в лечении...")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 15))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $notesText)
                    .frame(minHeight: 150)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    // MARK: - Действия

    private func addToCalendar() {
        let name = doctorNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name.isEmpty ? "Приём у врача" : "Приём у врача — \(name)"
        let store = EKEventStore()
        store.requestFullAccessToEvents { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                let event = EKEvent(eventStore: store)
                event.title = title
                event.startDate = selectedDate
                event.endDate = selectedDate.addingTimeInterval(3600)
                event.calendar = store.defaultCalendarForNewEvents
                event.notes = "Добавлено из RenalTracker"
                do {
                    try store.save(event, span: .thisEvent)
                    showCalendarSuccess = true
                } catch {
                    print("Ошибка добавления в календарь: \(error)")
                }
            }
        }
    }

    private func cancel() {
        if isNewVisit {
            modelContext.delete(visit)
            try? modelContext.save()
        }
        dismiss()
    }

    private func save() {
        visit.date = selectedDate

        let trimmedName = doctorNameText.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.doctorName = trimmedName.isEmpty ? nil : trimmedName

        let trimmedNotes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        visit.notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        try? modelContext.save()
    }
}
