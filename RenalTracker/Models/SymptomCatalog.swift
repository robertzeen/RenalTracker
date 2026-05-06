//
//  SymptomCatalog.swift
//  RenalTracker
//
//  Каталог предустановленных симптомов для записей самочувствия.
//  Пациент выбирает из этого списка при создании WellbeingEntry.
//  Кастомные симптомы добавляются пациентом и хранятся в UserDefaults.
//

import Foundation

enum SymptomCatalog {
    /// 9 предустановленных симптомов
    static let predefined: [String] = [
        "Слабость",
        "Головная боль",
        "Тошнота",
        "Озноб",
        "Отёки",
        "Боль в животе",
        "Боль в спине",
        "Бессонница",
        "Тревога",
    ]

    private static let customSymptomsKey = AppStorageKeys.customSymptoms

    /// Кастомные симптомы, добавленные пациентом
    static var custom: [String] {
        get {
            UserDefaults.standard.stringArray(forKey: customSymptomsKey) ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: customSymptomsKey)
        }
    }

    /// Все доступные симптомы: предустановленные + кастомные
    static var all: [String] {
        predefined + custom
    }

    /// Добавить кастомный симптом. Возвращает false если уже существует.
    @discardableResult
    static func addCustom(_ symptom: String) -> Bool {
        let trimmed = symptom.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard !all.contains(trimmed) else { return false }
        var current = custom
        current.append(trimmed)
        custom = current
        return true
    }

    /// Удалить кастомный симптом
    static func removeCustom(_ symptom: String) {
        var current = custom
        current.removeAll { $0 == symptom }
        custom = current
    }
}
