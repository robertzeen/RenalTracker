//
//  DoctorVisit.swift
//  RenalTracker
//

import Foundation
import SwiftData

@Model
final class DoctorVisit: Identifiable {
    var id: UUID
    var date: Date
    var doctorName: String?
    var notes: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        doctorName: String? = nil,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.doctorName = doctorName
        self.notes = notes
        self.createdAt = createdAt
    }
}

