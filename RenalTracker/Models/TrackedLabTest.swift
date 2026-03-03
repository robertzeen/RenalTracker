//
//  TrackedLabTest.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class TrackedLabTest {
    /// Название анализа (например, "Креатинин")
    var name: String
    /// Единица измерения (например, "мкмоль/л")
    var unit: String
    /// Нижняя граница референсного диапазона (для мужчин, по умолчанию)
    var referenceMin: Double?
    /// Верхняя граница референсного диапазона (для мужчин, по умолчанию)
    var referenceMax: Double?
    /// Является ли анализ пользовательским (не из предзаписанной базы)
    var isCustom: Bool
    /// Дата создания отслеживаемого анализа
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LabResult.trackedTest)
    var results: [LabResult] = []

    init(
        name: String,
        unit: String,
        referenceMin: Double? = nil,
        referenceMax: Double? = nil,
        isCustom: Bool = false,
        createdAt: Date = Date()
    ) {
        self.name = name
        self.unit = unit
        self.referenceMin = referenceMin
        self.referenceMax = referenceMax
        self.isCustom = isCustom
        self.createdAt = createdAt
    }
}

