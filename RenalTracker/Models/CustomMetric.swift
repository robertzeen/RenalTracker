//
//  CustomMetric.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class CustomMetric {
    var id: UUID
    var name: String
    var unit: String
    var icon: String
    var isActive: Bool
    var isCustom: Bool
    var sortOrder: Int
    @Relationship(deleteRule: .cascade)
    var entries: [CustomMetricEntry]
    var createdAt: Date

    init(name: String, unit: String, icon: String,
         isActive: Bool = false,
         isCustom: Bool = false,
         sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.unit = unit
        self.icon = icon
        self.isActive = isActive
        self.isCustom = isCustom
        self.sortOrder = sortOrder
        self.entries = []
        self.createdAt = Date()
    }
}
