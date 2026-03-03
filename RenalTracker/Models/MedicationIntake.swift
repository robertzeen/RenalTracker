//
//  MedicationIntake.swift
//  RenalTracker
//

import Foundation
import SwiftData

/// Фактический приём лекарства в конкретный день.
@Model
final class MedicationIntake {
    /// Дата и время фактического приёма
    var date: Date
    /// Был ли приём отмечен как выполненный
    var isTaken: Bool

    var medication: Medication

    init(date: Date = Date(), isTaken: Bool = true, medication: Medication) {
        self.date = date
        self.isTaken = isTaken
        self.medication = medication
    }
}

