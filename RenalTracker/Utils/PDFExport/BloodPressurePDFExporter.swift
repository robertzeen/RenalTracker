//
//  BloodPressurePDFExporter.swift
//  RenalTracker
//
//  Генерирует PDF-отчёт по давлению и пульсу через PDFReportRenderer.
//  Принимает только value-type данные — безопасно передавать в Task.detached.
//

import Foundation

enum BloodPressurePDFExporter {

    struct Record {
        let date: Date
        let systolic: Int
        let diastolic: Int
        let pulse: Int
    }

    static func makeData(
        records: [Record],
        periodDescription: String,
        patientName: String?
    ) -> Data {
        PDFExporter.makeData { r in
            r.drawHeader(
                reportTitle: "Отчёт по давлению и пульсу",
                patientName: patientName,
                periodDescription: periodDescription
            )
            r.drawTable(
                headers: ["Дата", "Время", "Сист.", "Диаст.", "Пульс"],
                columnWidthFractions: [0.25, 0.15, 0.2, 0.2, 0.2],
                rows: records.map { rec in
                    [
                        DateFormatter.russianDate.string(from: rec.date),
                        DateFormatter.russianTime.string(from: rec.date),
                        "\(rec.systolic)",
                        "\(rec.diastolic)",
                        "\(rec.pulse)"
                    ]
                }
            )
            let systolicValues  = records.map { Double($0.systolic) }
            let diastolicValues = records.map { Double($0.diastolic) }
            let pulseValues     = records.map { Double($0.pulse) }
            r.drawStats(lines: [
                statsLine(name: "Систолическое", values: systolicValues),
                statsLine(name: "Диастолическое", values: diastolicValues),
                statsLine(name: "Пульс", values: pulseValues)
            ].filter { !$0.isEmpty })
        }
    }

    static func fileURL(from data: Data) throws -> URL {
        try PDFExporter.saveToTempFile(data: data, fileNamePrefix: "BP")
    }

    // MARK: - Private

    private static func statsLine(name: String, values: [Double]) -> String {
        guard let min = values.min(), let max = values.max() else { return "" }
        let avg = values.reduce(0, +) / Double(values.count)
        return String(format: "%@: мин %.0f, макс %.0f, ср %.1f", name, min, max, avg)
    }
}
