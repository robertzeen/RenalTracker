//
//  HomeMetricsView.swift
//  RenalTracker
//

import SwiftUI

struct HomeMetricsView: View {
    let latestBloodPressure: BloodPressure?
    let latestWeight: Weight?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние показатели")
                .font(.headline)
            HStack(spacing: 12) {
                metricCard(
                    title: "Давление",
                    valueText: bpValueText,
                    dateText: bpDateText,
                    hasData: latestBloodPressure != nil
                )
                metricCard(
                    title: "Вес",
                    valueText: weightValueText,
                    dateText: weightDateText,
                    hasData: latestWeight != nil
                )
            }
        }
    }

    // MARK: - Helpers

    private var bpValueText: String {
        guard let bp = latestBloodPressure else { return "" }
        return "\(bp.systolic)/\(bp.diastolic)"
    }

    private var bpDateText: String {
        guard let bp = latestBloodPressure else { return "" }
        return DateFormatter.russianDateTime.string(from: bp.date)
    }

    private var weightValueText: String {
        guard let w = latestWeight else { return "" }
        let value = w.valueKg
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) кг"
            : "\(value) кг"
    }

    private var weightDateText: String {
        guard let w = latestWeight else { return "" }
        return DateFormatter.russianDateTime.string(from: w.date)
    }

    private func metricCard(title: String, valueText: String, dateText: String, hasData: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if hasData {
                Text(valueText)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Пока нет данных.\nМожно добавить на вкладке «Метрики».")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}
