//
//  LabResultsPDFExporter.swift
//  RenalTracker
//
//  Генерирует сводный PDF-отчёт по всем отслеживаемым анализам.
//  Принимает только value-type данные — безопасно передавать в Task.detached.
//

import Foundation

enum LabResultsPDFExporter {

    struct Test {
        let name: String
        let unit: String
        let results: [LabTestDetailPDFExporter.Result]
    }

    static func makeData(tests: [Test], patientName: String?) -> Data {
        PDFExporter.makeData { r in
            r.drawHeader(
                reportTitle: "Лабораторные анализы",
                patientName: patientName,
                periodDescription: nil
            )

            for test in tests where !test.results.isEmpty {
                let sortedDesc = test.results.sorted { $0.date > $1.date }
                r.drawSectionTitle(test.name)
                r.drawTable(
                    headers: ["Дата", "Значение"],
                    columnWidthFractions: [0.4, 0.6],
                    rows: sortedDesc.map { res in
                        let valueStr = test.unit.isEmpty
                            ? String(format: "%.2f", res.value)
                            : String(format: "%.2f %@", res.value, test.unit)
                        return [DateFormatter.russianDate.string(from: res.date), valueStr]
                    }
                )
            }
        }
    }
}
