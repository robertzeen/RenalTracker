//
//  WellBeing.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class WellBeing {
    var weakness: Int      // слабость 1–5
    var headache: Int      // головная боль 1–5
    var swelling: Int     // отёки 1–5
    var date: Date

    init(weakness: Int = 1, headache: Int = 1, swelling: Int = 1, date: Date = Date()) {
        self.weakness = min(5, max(1, weakness))
        self.headache = min(5, max(1, headache))
        self.swelling = min(5, max(1, swelling))
        self.date = date
    }
}
