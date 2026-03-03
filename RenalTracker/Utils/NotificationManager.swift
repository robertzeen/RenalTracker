//
//  NotificationManager.swift
//  RenalTracker
//

import Foundation
import UserNotifications
import SwiftData

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
        content.sound = .default

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
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: "lab_test", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    /// Полностью пересоздаёт уведомления по приёму лекарств.
    /// Вызывать при изменении списка лекарств или их расписания.
    func rescheduleMedicationNotifications(for medications: [Medication]) {
        // Сначала удаляем все ранее созданные уведомления med_*
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self = self else { return }

            let medIds = requests
                .map(\.identifier)
                .filter { $0.hasPrefix("med_") }

            self.center.removePendingNotificationRequests(withIdentifiers: medIds)

            // Затем создаём новые уведомления на основе актуального списка
            self.scheduleNotifications(for: medications)
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
    private func scheduleNotifications(for medications: [Medication]) {
        let activeMeds = medications.filter { $0.isActive && !$0.daysOfWeek.isEmpty }
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
            scheduleNotification(for: meds, key: key)
        }
    }

    private func scheduleNotification(for medications: [Medication], key: Key) {
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
        content.sound = .default

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
        if let amount = med.dosageAmount {
            if med.dosageUnit.isEmpty {
                return String(format: "%.1f", amount)
            } else {
                return String(format: "%.1f %@", amount, med.dosageUnit)
            }
        } else {
            return med.dosageUnit.isEmpty ? med.name : "\(med.name) \(med.dosageUnit)"
        }
    }
}

