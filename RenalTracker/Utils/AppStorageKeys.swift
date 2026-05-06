//
//  AppStorageKeys.swift
//  RenalTracker
//

import Foundation

/// Централизованные ключи для UserDefaults / @AppStorage.
/// Использовать для защиты от опечаток в строковых литералах.
///
/// Типовой паттерн использования:
///     @AppStorage(AppStorageKeys.notificationsEnabled) var isEnabled = true
///     UserDefaults.standard.bool(forKey: AppStorageKeys.bpReminderEnabled)
enum AppStorageKeys {

    // MARK: - Уведомления

    /// Общий тумблер уведомлений о лекарствах. Bool. По умолчанию true.
    static let notificationsEnabled = "notificationsEnabled"

    /// Уведомления с interruptionLevel .timeSensitive (приходят даже в «Не беспокоить»). Bool. По умолчанию false.
    static let criticalNotificationsEnabled = "criticalNotificationsEnabled"

    /// Напоминания об измерении давления утром/вечером. Bool. По умолчанию false.
    static let bpReminderEnabled = "bpReminderEnabled"

    /// Напоминание о взвешивании (ежедневно). Bool. По умолчанию false.
    static let weightReminderEnabled = "weightReminderEnabled"

    /// Время утреннего напоминания о давлении. Date. По умолчанию 08:00.
    static let bpMorningReminderTime = "bpMorningReminderTime"

    /// Время вечернего напоминания о давлении. Date. По умолчанию 20:00.
    static let bpEveningReminderTime = "bpEveningReminderTime"

    /// Время ежедневного напоминания о взвешивании. Date. По умолчанию 07:30.
    static let weightReminderTime = "weightReminderTime"

    // MARK: - Калибровка EventKit-интеграций

    /// Timestamp (секунды с 1970) последнего добавления приёма к врачу в Календарь iOS. Double.
    static let doctorCalendarAddedTimestamp = "doctorCalendarAddedTimestamp"

    /// Timestamp (секунды с 1970) последнего добавления сдачи анализов в Календарь iOS. Double.
    static let labCalendarAddedTimestamp = "labCalendarAddedTimestamp"

    // MARK: - Журнал

    /// Кастомные симптомы, добавленные пациентом вручную. [String].
    static let customSymptoms = "customSymptoms"
}
