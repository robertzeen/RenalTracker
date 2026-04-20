//
//  LabTestDetailPDFExporter.swift
//  RenalTracker
//
//  Генерирует PDF-отчёт по одному анализу: шапка, график, таблица, итоги.
//  Принимает только value-type данные — безопасно передавать в Task.detached.
//

import Foundation
import UIKit

enum LabTestDetailPDFExporter {

    struct Result {
        let date: Date
        let value: Double
    }

    static func makeData(
        testName: String,
        unit: String,
        results: [Result],
        periodDescription: String?,
        patientName: String?,
        chartImage: UIImage?
    ) -> Data {
        PDFExporter.makeData { r in
            r.drawHeader(
                reportTitle: "Отчёт по анализу: \(testName)",
                patientName: patientName,
                periodDescription: periodDescription
            )
            if !unit.isEmpty {
                r.drawLines(["Единица измерения: \(unit)"])
            }

            if let chartImage {
                r.drawChart(chartImage, height: 240)
            }

            let sortedDesc = results.sorted { $0.date > $1.date }
            r.drawTable(
                headers: ["Дата", "Значение"],
                columnWidthFractions: [0.4, 0.6],
                rows: sortedDesc.map { res in
                    let valueStr = unit.isEmpty
                        ? String(format: "%.2f", res.value)
                        : String(format: "%.2f %@", res.value, unit)
                    return [DateFormatter.russianDate.string(from: res.date), valueStr]
                }
            )

            let values = results.map { $0.value }
            if let minVal = values.min(), let maxVal = values.max(), !values.isEmpty {
                let avg = values.reduce(0, +) / Double(values.count)
                let suffix = unit.isEmpty ? "" : " \(unit)"
                r.drawStats(lines: [
                    String(format: "Минимум: %.2f%@", minVal, suffix),
                    String(format: "Максимум: %.2f%@", maxVal, suffix),
                    String(format: "Среднее: %.2f%@", avg, suffix)
                ])
            }
        }
    }
}
