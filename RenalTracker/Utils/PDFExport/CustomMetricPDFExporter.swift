//
//  CustomMetricPDFExporter.swift
//  RenalTracker
//
//  Генерирует PDF-отчёт по кастомной метрике через PDFReportRenderer.
//  Принимает только value-type данные — безопасно передавать в Task.detached.
//

import Foundation

enum CustomMetricPDFExporter {

    struct Entry {
        let date: Date
        let value: Double
    }

    static func makeData(
        metricName: String,
        unit: String,
        entries: [Entry],
        patientName: String?
    ) -> Data {
        PDFExporter.makeData { r in
            r.drawHeader(
                reportTitle: "Отчёт: \(metricName)",
                patientName: patientName,
                periodDescription: nil
            )
            r.drawTable(
                headers: ["Дата и время", "Значение"],
                columnWidthFractions: [0.55, 0.45],
                rows: entries.map { e in
                    [
                        DateFormatter.russianDateTime.string(from: e.date),
                        "\(formatNumber(e.value)) \(unit)"
                    ]
                }
            )
            let values = entries.map { $0.value }
            if let minVal = values.min(), let maxVal = values.max(), !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                r.drawStats(lines: [
                    "Записей: \(entries.count)",
                    "Минимум: \(formatNumber(minVal)) \(unit)",
                    "Максимум: \(formatNumber(maxVal)) \(unit)",
                    "Среднее: \(formatNumber(avg)) \(unit)"
                ])
            }
        }
    }

    static func fileURL(from data: Data, metricName: String) throws -> URL {
        try PDFExporter.saveToTempFile(data: data, fileNamePrefix: metricName)
    }

    // MARK: - Private

    private static func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }
}
