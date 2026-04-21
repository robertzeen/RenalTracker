//
//  NotificationManager.swift
//  RenalTracker
//

import Foundation
import UserNotifications
import SwiftData

/// Все настройки ежедневных напоминаний об измерениях.
/// Собирается в call-site из @AppStorage/@State и передаётся в NotificationManager.
/// Value-type — безопасен для передачи между изоляциями.
struct ReminderSettings {
    let bpEnabled: Bool
    let bpMorning: Date
    let bpEvening: Date
    let weightEnabled: Bool
    let weightTime: Date
}

/// Управление локальными уведомлениями по приёму лекарств.
///
/// Уведомления создаются не под каждое лекарство, а под
/// каждое уникальное сочетание «день недели + время приёма».
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Публичное API

    /// Запрашивает разрешение на отправку уведомлений.
    func requestAuthorizationIfNeeded() {
        center.getNotificationSettings { [weak self] settings in
            guard let self = self else { return }
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
            default:
                break
            }
        }
    }

    /// Планирует или отменяет уведомление о приёме у врача.
    /// — date == nil: отменяет уведомление с id "doctor_appointment".
    /// — date в будущем: одно уведомление за 1 день до приёма в 10:00.
    /// Если указано имя врача, оно добавляется в текст уведомления.
    func scheduleDoctorAppointmentNotification(date: Date?, doctorName: String? = nil) {
        center.removePendingNotificationRequests(withIdentifiers: ["doctor_appointment"])
        guard let date = date else { return }

        let appointmentStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: Date())
        guard appointmentStart > todayStart else { return }

        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: date) else { return }
        var comps = calendar.dateComponents([.year, .month, .day], from: dayBefore)
        comps.hour = 10
        comps.minute = 0

        let timeString = DateFormatter.russianTime.string(from: date)
        let trimmedName = doctorName?.trimmingCharacters(in: .whitespacesAndNewlines)

        let content = UNMutableNotificationContent()
        content.title = "Завтра в \(timeString) приём у нефролога"
        if let name = trimmedName, !name.isEmpty {
            content.body = "Врач: \(name). Не забудьте взять результаты анализов."
        } else {
            content.body = "Не забудьте взять результаты анализов."
        }
        content.sound = UNNotificationSound(named: UNNotificationSoundName("notification.caf"))
        content.badge = 1

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "doctor_appointment", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Планирует или отменяет уведомление о ближайшей сдаче анализов.
    /// — date == nil: отменяет уведомление с id "lab_test".
    /// — date в будущем: одно уведомление за 1 день до даты в 10:00.
    func scheduleLabTestNotification(date: Date?) {
        center.removePendingNotificationRequests(withIdentifiers: ["lab_test"])
        guard let date = date else { return }

        let testStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: Date())
        guard testStart > todayStart else { return }

        guard let dayBefore = calendar.date(byAdding: .day, value: -1, to: date) else { return }
        var comps = calendar.dateComponents([.year, .month, .day], from: dayBefore)
        comps.hour = 10
        comps.minute = 0

        let timeString = DateFormatter.russianTime.string(from: date)

        let content = UNMutableNotificationContent()
        content.title = "Завтра в \(timeString) сдача анализов 🧪"
        content.body = "Не забудьте взять направление и список показателей"
        content.sound = UNNotificationSound(named: UNNotificationSoundName("notification.caf"))
        content.badge = 1

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "lab_test", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Полностью пересоздаёт уведомления по приёму лекарств.
    /// Вызывать при изменении списка лекарств или их расписания.
    func rescheduleMedicationNotifications(for medications: [Medication], enabled: Bool, critical: Bool) {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }
            let medIds = requests.map(\.identifier).filter { $0.hasPrefix("med_") }
            self.center.removePendingNotificationRequests(withIdentifiers: medIds)
            guard enabled else { return }
            self.scheduleNotifications(for: medications, critical: critical)
        }
    }

    // MARK: - Внутренняя логика

    /// Ключ для группировки уведомлений по (день недели, время).
    private struct Key: Hashable {
        let weekday: Int
        let hour: Int
        let minute: Int
    }

    /// Группирует лекарства по (день недели, время) и создаёт уведомления для каждой группы.
    private func scheduleNotifications(for medications: [Medication], critical: Bool) {
        let activeMeds = medications.filter { $0.isActive && !$0.daysOfWeek.isEmpty }

        print("[Notifications] scheduleNotifications: \(activeMeds.count) активных лекарств")
        for med in activeMeds {
            print("[Notifications]   \(med.name), time: \(med.time), days: \(med.daysOfWeek)")
        }

        guard !activeMeds.isEmpty else { return }

        var groups: [Key: [Medication]] = [:]

        for med in activeMeds {
            let components = calendar.dateComponents([.hour, .minute], from: med.time)
            let hour = components.hour ?? 0
            let minute = components.minute ?? 0

            for weekday in med.daysOfWeek {
                let key = Key(weekday: weekday, hour: hour, minute: minute)
                groups[key, default: []].append(med)
            }
        }

        for (key, meds) in groups {
            scheduleNotification(for: meds, key: key, critical: critical)
        }
    }

    private func scheduleNotification(for medications: [Medication], key: Key, critical: Bool) {
        guard let first = medications.first else { return }

        let timeString = DateFormatter.russianTime.string(from: first.time)

        let title: String
        if medications.count == 1 {
            title = "Время принять лекарство 💊 — \(timeString)"
        } else {
            title = "Время принять лекарства 💊 — \(timeString)"
        }

        let body = medications
            .map { dosageDescription(for: $0) }
            .joined(separator: ", ")

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.badge = 1

        if critical {
            content.interruptionLevel = .timeSensitive
            content.sound = .defaultCriticalSound(withAudioVolume: 0.8)
        } else {
            content.interruptionLevel = .active
            content.sound = UNNotificationSound(named: UNNotificationSoundName("notification.caf"))
        }

        var dateComponents = DateComponents()
        dateComponents.weekday = key.weekday
        dateComponents.hour = key.hour
        dateComponents.minute = key.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let identifier = "med_\(key.weekday)_\(key.hour)_\(key.minute)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    private func dosageDescription(for med: Medication) -> String {
        let dosage = med.formattedDosage
        return dosage.isEmpty ? med.name : "\(med.name) \(dosage)"
    }

    // MARK: - Напоминания об измерениях

    /// Пересоздаёт ежедневные напоминания об измерении давления и веса.
    func scheduleMeasurementReminders(_ settings: ReminderSettings) {
        center.removePendingNotificationRequests(
            withIdentifiers: ["bp_morning", "bp_evening", "weight_reminder"]
        )

        if settings.bpEnabled {
            scheduleDaily(
                id: "bp_morning",
                time: settings.bpMorning,
                title: "Измерьте давление 💊",
                body: "Не забудьте измерить давление и пульс"
            )
            scheduleDaily(
                id: "bp_evening",
                time: settings.bpEvening,
                title: "Измерьте давление 💊",
                body: "Вечернее измерение давления и пульса"
            )
        }

        if settings.weightEnabled {
            scheduleDaily(
                id: "weight_reminder",
                time: settings.weightTime,
                title: "Взвесьтесь ⚖️",
                body: "Время зафиксировать вес"
            )
        }
    }

    private func scheduleDaily(id: String, time: Date, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("notification.caf"))
        content.badge = 1

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    // MARK: - Управление уведомлениями о лекарствах

    /// Отменяет все уведомления о лекарствах асинхронно.
    func disableMedicationNotifications() {
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("med_") }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Обновляет звук и уровень прерывания для уже запланированных
    /// уведомлений о лекарствах без необходимости доступа к SwiftData.
    func updateNotifications(enabled: Bool, critical: Bool) {
        guard enabled else { return }

        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }

            let medRequests = requests.filter { $0.identifier.hasPrefix("med_") }
            guard !medRequests.isEmpty else { return }

            let ids = medRequests.map { $0.identifier }
            self.center.removePendingNotificationRequests(withIdentifiers: ids)

            for request in medRequests {
                let updated = UNMutableNotificationContent()
                updated.title = request.content.title
                updated.body  = request.content.body
                updated.badge = request.content.badge

                if critical {
                    updated.interruptionLevel = .timeSensitive
                    updated.sound = .defaultCriticalSound(withAudioVolume: 0.8)
                } else {
                    updated.interruptionLevel = .active
                    updated.sound = UNNotificationSound(
                        named: UNNotificationSoundName("notification.caf"))
                }

                guard let trigger = request.trigger else { continue }
                let newRequest = UNNotificationRequest(
                    identifier: request.identifier,
                    content: updated,
                    trigger: trigger
                )
                self.center.add(newRequest, withCompletionHandler: nil)
            }
        }
    }

    // MARK: - Диагностика

    /// Печатает в консоль все запланированные уведомления (для отладки).
    func printScheduledNotifications() {
        center.getPendingNotificationRequests { requests in
            print("=== Запланированные уведомления: \(requests.count) ===")
            for request in requests {
                print("ID: \(request.identifier)")
                print("Trigger: \(String(describing: request.trigger))")
                print("Content: \(request.content.title) — \(request.content.body)")
                print("---")
            }
            if requests.isEmpty {
                print("(нет запланированных уведомлений)")
            }
        }
    }
}

