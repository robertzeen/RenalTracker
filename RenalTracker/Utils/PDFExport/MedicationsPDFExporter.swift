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

        // Группируем по времени приёма, сохраняем порядок от раннего к позднему.
        // Внутри каждой группы — сортировка по имени препарата (чтобы порядок был стабильным).
        let grouped = Dictionary(grouping: rows, by: { $0.time })
        let sortedGroups: [(time: String, rows: [Row])] = grouped
            .map { (time: $0.key, rows: $0.value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.time < $1.time }

        return PDFExporter.makeData { r in
            r.drawHeader(
                reportTitle: "Список принимаемых лекарств",
                patientName: patientName,
                periodDescription: nil
            )
            for group in sortedGroups {
                r.drawSectionTitle(group.time)
                r.drawTable(
                    headers: ["Препарат", "Дозировка"],
                    columnWidthFractions: [0.65, 0.35],
                    rows: group.rows.map { [$0.name, $0.dosage] },
                    monospaced: false
                )
            }
        }
    }

    static func fileURL(from data: Data) throws -> URL {
        try PDFExporter.saveToTempFile(data: data, fileNamePrefix: "Medications")
    }
}
