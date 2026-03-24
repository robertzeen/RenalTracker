//
//  DoctorAppointmentSheet.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import EventKit

struct DoctorAppointmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let userProfile: UserProfile?

    @State private var selectedDate: Date
    @State private var doctorName: String
    @State private var showDatePicker = false
    @State private var showTimePicker = false
    @AppStorage("doctorCalendarAddedTimestamp") private var calendarAddedTimestamp: Double = 0

    init(userProfile: UserProfile?) {
        self.userProfile = userProfile
        _doctorName = State(initialValue: userProfile?.nextDoctorName ?? "")

        if let date = userProfile?.nextDoctorAppointment {
            _selectedDate = State(initialValue: date)
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.day = (components.day ?? 0) + 1
            components.hour = 10
            components.minute = 0
            _selectedDate = State(initialValue: Calendar.current.date(from: components) ?? Date())
        }
    }

    // MARK: - Вычисляемые свойства

    private var addedToCalendar: Bool {
        guard calendarAddedTimestamp > 0 else { return false }
        let saved = Date(timeIntervalSince1970: calendarAddedTimestamp)
        return Calendar.current.isDate(saved, equalTo: selectedDate, toGranularity: .minute)
    }

    private var daysUntil: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: selectedDate)
        ).day ?? 0
    }

    private var minimumDate: Date {
        let calendar = Calendar.current
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())
        if selectedDay == today {
            return Date()
        } else {
            return calendar.startOfDay(for: selectedDate)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Карточка врача
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
                            TextField("ФИО врача (опционально)", text: $doctorName)
                                .font(.system(size: 15, weight: .medium))
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    // Карточка даты и времени
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ДАТА")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(DateFormatter.russianDate.string(from: selectedDate))
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
                            DatePicker("", selection: $selectedDate, in: Date()..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .padding(.horizontal, 8)
                                .onChange(of: selectedDate) { _, _ in
                                    showDatePicker = false
                                }
                        }

                        Divider()

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ВРЕМЯ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(DateFormatter.russianTime.string(from: selectedDate))
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
                            DatePicker("", selection: $selectedDate, in: minimumDate..., displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .labelsHidden()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    // Кнопка / индикатор календаря
                    if addedToCalendar {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Добавлено в календарь")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 0.5))
                    } else {
                        Button {
                            let name = doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let title = name.isEmpty ? "Приём у врача" : "Приём у врача — \(name)"
                            addToCalendar(title: title) {
                                calendarAddedTimestamp = selectedDate.timeIntervalSince1970
                            }
                        } label: {
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
                }
                .padding(16)
            }
            .navigationTitle("Приём у врача")
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
            }
        }
    }

    // MARK: - Действия

    private func save() {
        let rawName = doctorName.trimmingCharacters(in: .whitespacesAndNewlines)
        userProfile?.nextDoctorName = rawName.isEmpty ? nil : rawName
        userProfile?.nextDoctorAppointment = selectedDate
        try? modelContext.save()
        NotificationManager.shared.scheduleDoctorAppointmentNotification(
            date: selectedDate,
            doctorName: rawName.isEmpty ? nil : rawName
        )
    }

    private func addToCalendar(title: String, completion: @escaping () -> Void) {
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
                    completion()
                } catch {
                    print("Ошибка добавления в календарь: \(error)")
                }
            }
        }
    }
}
