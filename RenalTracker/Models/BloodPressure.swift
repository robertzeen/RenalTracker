//
//  BloodPressure.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class BloodPressure {
    var systolic: Int      // систолическое (верхнее)
    var diastolic: Int     // диастолическое (нижнее)
    var pulse: Int         // пульс
    var date: Date

    init(systolic: Int, diastolic: Int, pulse: Int, date: Date = Date()) {
        self.systolic = systolic
        self.diastolic = diastolic
        self.pulse = pulse
        self.date = date
    }
}
