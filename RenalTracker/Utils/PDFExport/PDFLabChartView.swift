//
//  PDFLabChartView.swift
//  RenalTracker
//
//  SwiftUI-чарт для рендеринга в UIImage через ImageRenderer.
//  Используется в LabTestDetailPDFExporter.
//  Принимает value-type данные — не зависит от SwiftData-моделей.
//

import SwiftUI
import Charts

struct PDFLabChartView: View {
    struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    let points: [Point]

    var body: some View {
        let sorted  = points.sorted { $0.date < $1.date }
        let values  = sorted.map { $0.value }
        let minVal  = values.min() ?? 0
        let maxVal  = values.max() ?? 0
        let padding = (maxVal - minVal) * 0.1
        let minY    = max(0, minVal - padding)
        let maxY    = maxVal + padding

        return Chart {
            ForEach(sorted) { p in
                LineMark(x: .value("Дата", p.date), y: .value("Значение", p.value))
                    .foregroundStyle(.blue)
                PointMark(x: .value("Дата", p.date), y: .value("Значение", p.value))
                    .foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
        .padding()
    }
}
