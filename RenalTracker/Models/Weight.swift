//
//  Weight.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class Weight {
    var valueKg: Double
    var date: Date

    init(valueKg: Double, date: Date = Date()) {
        self.valueKg = valueKg
        self.date = date
    }
}
