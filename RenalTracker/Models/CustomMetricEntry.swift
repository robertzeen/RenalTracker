//
//  CustomMetricEntry.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class CustomMetricEntry {
    var id: UUID
    var value: Double
    var date: Date
    var metric: CustomMetric?

    init(value: Double, date: Date = Date(),
         metric: CustomMetric? = nil) {
        self.id = UUID()
        self.value = value
        self.date = date
        self.metric = metric
    }
}
