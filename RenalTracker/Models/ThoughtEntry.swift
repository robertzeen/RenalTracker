//
//  ThoughtEntry.swift
//  RenalTracker
//
//  Свободная текстовая запись для мыслей и рефлексии.
//  Связь с визитами — через диапазон дат, не через внешний ключ.
//

import Foundation
import SwiftData

@Model
final class ThoughtEntry {
    var id: UUID
    var date: Date
    var text: String
    var createdAt: Date

    init(date: Date = Date(),
         text: String = "") {
        self.id = UUID()
        self.date = date
        self.text = text
        self.createdAt = Date()
    }
}
