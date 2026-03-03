//
//  LabResult.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class LabResult {
    /// Название анализа (дублирует `trackedTest?.name` для удобства запросов и обратной совместимости)
    var name: String
    /// Значение анализа
    var value: Double
    /// Единица измерения (дублирует `trackedTest?.unit`)
    var unit: String
    /// Дата и время сдачи анализа
    var date: Date
    /// Отслеживаемый анализ, к которому относится результат (необязательно для старых данных)
    var trackedTest: TrackedLabTest?

    init(
        name: String,
        value: Double,
        unit: String,
        date: Date = Date(),
        trackedTest: TrackedLabTest? = nil
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.date = date
        self.trackedTest = trackedTest
    }
}

