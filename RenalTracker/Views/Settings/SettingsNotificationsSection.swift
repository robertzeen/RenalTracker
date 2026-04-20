//
//  SettingsNotificationsSection.swift
//  RenalTracker
//
//  Полностью автономная секция: состояние хранится в @AppStorage и @State,
//  биндинги от контейнера не нужны.
//

import SwiftUI
import UserNotifications

struct SettingsNotificationsSection: View {
    @AppStorage(AppStorageKeys.notificationsEnabled) var notificationsEnabled = true
    @AppStorage(AppStorageKeys.criticalNotificationsEnabled) var criticalNotificationsEnabled = false
    @AppStorage(AppStorageKeys.bpReminderEnabled) var bpReminderEnabled = false
    @AppStorage(AppStorageKeys.weightReminderEnabled) var weightReminderEnabled = false

    @State private var bpMorningTime: Date
    @State private var bpEveningTime: Date
    @State private var weightReminderTime: Date

    @State private var showBPMorningPicker = false
    @State private var showBPEveningPicker = false
    @State private var showWeightPicker = false

    init() {
        _bpMorningTime = State(initialValue: UserDefaults.standard.object(forKey: AppStorageKeys.bpMorningReminderTime) as? Date
            ?? Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date())
        _bpEveningTime = State(initialValue: UserDefaults.standard.object(forKey: AppStorageKeys.bpEveningReminderTime) as? Date
            ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date())
        _weightReminderTime = State(initialValue: UserDefaults.standard.object(forKey: AppStorageKeys.weightReminderTime) as? Date
            ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 30)) ?? Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("УВЕДОМЛЕНИЯ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Уведомления о лекарствах
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Уведомления о лекарствах")
                            .font(.system(size: 15, weight: .medium))
                        Text("Напоминания по расписанию")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                NotificationManager.shared.updateNotifications()
                            } else {
                                NotificationManager.shared.disableMedicationNotifications()
                                criticalNotificationsEnabled = false
                            }
                        }
                }
                .padding(14)

                Divider().padding(.leading, 14)

                // В режиме «Не беспокоить»
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("В режиме «Не беспокоить»")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(notificationsEnabled ? .primary : .secondary)
                        Text("Уведомления о лекарствах всё равно придут")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $criticalNotificationsEnabled)
                        .labelsHidden()
                        .disabled(!notificationsEnabled)
                        .onChange(of: criticalNotificationsEnabled) { _, _ in
                            if notificationsEnabled {
                                NotificationManager.shared.updateNotifications()
                            }
                        }
                }
                .padding(14)

                Divider().padding(.leading, 14)

                // Напоминание о давлении
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Напоминание об измерении давления")
                            .font(.system(size: 15, weight: .medium))
                        Text("Утреннее и вечернее")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $bpReminderEnabled)
                        .labelsHidden()
                        .onChange(of: bpReminderEnabled) { _, enabled in
                            if !enabled {
                                showBPMorningPicker = false
                                showBPEveningPicker = false
                            }
                            NotificationManager.shared.scheduleMeasurementReminders()
                        }
                }
                .padding(14)

                if bpReminderEnabled {
                    Divider().padding(.leading, 14)

                    // Утреннее время
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("УТРЕННЕЕ ИЗМЕРЕНИЕ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(DateFormatter.russianTime.string(from: bpMorningTime))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: showBPMorningPicker ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                    .onTapGesture { showBPMorningPicker.toggle() }

                    if showBPMorningPicker {
                        Divider()
                        DatePicker("", selection: $bpMorningTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .frame(maxWidth: .infinity)
                            .onChange(of: bpMorningTime) { _, _ in
                                UserDefaults.standard.set(bpMorningTime, forKey: AppStorageKeys.bpMorningReminderTime)
                                NotificationManager.shared.scheduleMeasurementReminders()
                            }
                    }

                    Divider().padding(.leading, 14)

                    // Вечернее время
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ВЕЧЕРНЕЕ ИЗМЕРЕНИЕ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(DateFormatter.russianTime.string(from: bpEveningTime))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: showBPEveningPicker ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                    .onTapGesture { showBPEveningPicker.toggle() }

                    if showBPEveningPicker {
                        Divider()
                        DatePicker("", selection: $bpEveningTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .frame(maxWidth: .infinity)
                            .onChange(of: bpEveningTime) { _, _ in
                                UserDefaults.standard.set(bpEveningTime, forKey: AppStorageKeys.bpEveningReminderTime)
                                NotificationManager.shared.scheduleMeasurementReminders()
                            }
                    }
                }

                Divider().padding(.leading, 14)

                // Напоминание о взвешивании
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Напоминание о взвешивании")
                            .font(.system(size: 15, weight: .medium))
                        Text("Ежедневное утреннее")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $weightReminderEnabled)
                        .labelsHidden()
                        .onChange(of: weightReminderEnabled) { _, enabled in
                            if !enabled { showWeightPicker = false }
                            NotificationManager.shared.scheduleMeasurementReminders()
                        }
                }
                .padding(14)

                if weightReminderEnabled {
                    Divider().padding(.leading, 14)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ВРЕМЯ ВЗВЕШИВАНИЯ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(DateFormatter.russianTime.string(from: weightReminderTime))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: showWeightPicker ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                    .onTapGesture { showWeightPicker.toggle() }

                    if showWeightPicker {
                        Divider()
                        DatePicker("", selection: $weightReminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .frame(maxWidth: .infinity)
                            .onChange(of: weightReminderTime) { _, _ in
                                UserDefaults.standard.set(weightReminderTime, forKey: AppStorageKeys.weightReminderTime)
                                NotificationManager.shared.scheduleMeasurementReminders()
                            }
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))
        }
    }
}
