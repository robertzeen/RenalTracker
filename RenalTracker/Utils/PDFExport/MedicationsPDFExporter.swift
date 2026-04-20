//
//  MedicationsPDFExporter.swift
//  RenalTracker
//

import Foundation

enum MedicationsPDFExporter {

    struct Row {
        let name: String
        let dosage: String
        let time: String
    }

    static func generateData(rows: [Row], patientName: String?) -> Data? {
        guard !rows.isEmpty else { return nil }
        return PDFExporter.makeData { r in
            r.drawHeader(
                reportTitle: "Список принимаемых лекарств",
                patientName: patientName,
                periodDescription: nil
            )
            r.drawTable(
                headers: ["Препарат", "Дозировка", "Время приёма"],
                columnWidthFractions: [0.45, 0.25, 0.30],
                rows: rows.map { [$0.name, $0.dosage, $0.time] },
                monospaced: false
            )
        }
    }

    static func fileURL(from data: Data) throws -> URL {
        try PDFExporter.saveToTempFile(data: data, fileNamePrefix: "Medications")
    }
}
