//
//  UserProfile.swift
//  RenalTracker
//

import Foundation
import SwiftData

/// Категория пользователя: тип диализа или состояние после пересадки
enum UserCategory: String, Codable, CaseIterable {
    case hemodialysis = "Гемодиализ"
    case peritonealDialysis = "Перитонеальный диализ"
    case postTransplant = "После пересадки почки"
}

@Model
final class UserProfile {
    var categoryRaw: String
    /// Имя (обязательно в UI)
    var name: String
    /// Фамилия (опционально)
    var lastName: String?
    /// Возраст (опционально, можно рассчитать от даты рождения, но храним отдельно по запросу)
    var age: Int?
    /// Дата рождения (используется в будущем для более точных вычислений)
    var birthDate: Date
    /// Телефон пациента
    var patientPhone: String?
    /// Телефон врача
    var doctorPhone: String?
    /// ФИО лечащего врача
    var doctorName: String?
    /// Фото профиля в виде бинарных данных
    var photoData: Data?

    /// Данные по гемодиализу
    var hemoStartDate: Date?
    var hemoEndDate: Date?
    var hemoOngoing: Bool

    /// Данные по перитонеальному диализу
    var pdStartDate: Date?
    var pdEndDate: Date?
    var pdOngoing: Bool

    /// Дата трансплантации почки
    var transplantDate: Date?

    /// Следующий приём у врача (нефролога)
    var nextDoctorAppointment: Date?

    /// Имя врача для следующего приёма
    var nextDoctorName: String?

    /// Следующая сдача анализов
    var nextLabTest: Date?

    /// Флаг пройденного онбординга
    var hasCompletedOnboarding: Bool

    var category: UserCategory {
        get { UserCategory(rawValue: categoryRaw) ?? .hemodialysis }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        category: UserCategory,
        name: String = "",
        birthDate: Date = Date(),
        hasCompletedOnboarding: Bool = false
    ) {
        self.categoryRaw = category.rawValue
        self.name = name
        self.lastName = nil
        self.age = nil
        self.birthDate = birthDate
        self.patientPhone = nil
        self.doctorPhone = nil
        self.doctorName = nil
        self.photoData = nil
        self.hemoStartDate = nil
        self.hemoEndDate = nil
        self.hemoOngoing = false
        self.pdStartDate = nil
        self.pdEndDate = nil
        self.pdOngoing = false
        self.transplantDate = nil
        self.nextDoctorAppointment = nil
        self.nextDoctorName = nil
        self.nextLabTest = nil
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }
}
