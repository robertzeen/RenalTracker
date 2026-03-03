//
//  Medication.swift
//  RenalTracker
//

import Foundation
import SwiftData

/// Расписание приёма одного лекарства (одна комбинация дней + время).
@Model
final class Medication {
    /// Наименование лекарства
    var name: String
    /// Количество (число), например 5
    var dosageAmount: Double?
    /// Единица измерения, например "мг" (опционально)
    var dosageUnit: String
    /// Дни недели, когда принимается препарат (значения Calendar.Component.weekday 1...7)
    var daysOfWeek: [Int]
    /// Время приёма (дата берётся произвольная, учитывается только время)
    var time: Date
    /// Является ли расписание активным
    var isActive: Bool

    @Relationship(deleteRule: .cascade, inverse: \MedicationIntake.medication)
    var intakes: [MedicationIntake] = []

    init(
        name: String,
        dosageAmount: Double? = nil,
        dosageUnit: String = "",
        daysOfWeek: [Int],
        time: Date,
        isActive: Bool = true
    ) {
        self.name = name
        self.dosageAmount = dosageAmount
        self.dosageUnit = dosageUnit
        self.daysOfWeek = daysOfWeek
        self.time = time
        self.isActive = isActive
    }
}

