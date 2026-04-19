//
//  WeightPDFExporter.swift
//  RenalTracker
//
//  Генерирует PDF-отчёт по весу через PDFReportRenderer.
//  Принимает только value-type данные — безопасно передавать в Task.detached.
//

import Foundation

enum WeightPDFExporter {

    struct Record {
        let date: Date
        let valueKg: Double
    }

    static func makeData(
        records: [Record],
        periodDescription: String?,
        patientName: String?
    ) -> Data {
        PDFExporter.makeData { r in
            r.drawHeader(
                reportTitle: "Отчёт по весу",
                patientName: patientName,
                periodDescription: periodDescription
            )
            r.drawTable(
                headers: ["Дата и время", "Вес (кг)"],
                columnWidthFractions: [0.5, 0.5],
                rows: records.map { rec in
                    [
                        DateFormatter.russianDateTime.string(from: rec.date),
                        formatted(rec.valueKg)
                    ]
                }
            )
        }
    }

    static func fileURL(from data: Data) throws -> URL {
        try PDFExporter.saveToTempFile(data: data, fileNamePrefix: "Weight")
    }

    // MARK: - Private

    private static func formatted(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
