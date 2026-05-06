//
//  WellbeingEntry.swift
//  RenalTracker
//
//  Запись о самочувствии пациента. Содержит общую оценку (1-5)
//  и опциональный набор симптомов из каталога или кастомных.
//  Связь с визитами — через диапазон дат, не через внешний ключ.
//

import Foundation
import SwiftData

@Model
final class WellbeingEntry {
    var id: UUID
    var date: Date
    var wellbeing: Int        // 1 (плохо) — 5 (хорошо)
    var symptoms: [String]    // теги симптомов: "Слабость", "Головная боль", etc.
    var createdAt: Date

    init(date: Date = Date(),
         wellbeing: Int = 3,
         symptoms: [String] = []) {
        self.id = UUID()
        self.date = date
        self.wellbeing = wellbeing
        self.symptoms = symptoms
        self.createdAt = Date()
    }
}
