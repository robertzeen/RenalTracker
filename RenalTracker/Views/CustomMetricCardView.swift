//
//  CustomMetricCardView.swift
//  RenalTracker
//

import SwiftUI
import Charts

struct CustomMetricCardView: View {
    let metric: CustomMetric
    let chartPeriod: ChartPeriod

    @State private var isShowingAddEntry = false

    private var sortedEntries: [CustomMetricEntry] {
        metric.entries.sorted { $0.date > $1.date }
    }

    private var filteredEntries: [CustomMetricEntry] {
        switch chartPeriod {
        case .days7:
            return sortedEntries.filter { $0.date >= Date().addingTimeInterval(-7 * 24 * 3600) }
        case .days30:
            return sortedEntries.filter { $0.date >= Date().addingTimeInterval(-30 * 24 * 3600) }
        case .all:
            return sortedEntries
        }
    }

    private var lastEntry: CustomMetricEntry? {
        sortedEntries.first
    }

    private var formattedLastValue: String {
        guard let entry = lastEntry else { return "Нет данных" }
        let value = entry.value
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) \(metric.unit)"
        } else {
            return String(format: "%.1f \(metric.unit)", value)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 12))
                            .foregroundStyle(.blue)
                        Text(metric.name.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("Последнее: \(formattedLastValue)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isShowingAddEntry = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(14)

            Divider()

            // График или заглушка
            if filteredEntries.count >= 2 {
                let chartEntries = filteredEntries.sorted { $0.date < $1.date }
                Chart {
                    ForEach(chartEntries) { entry in
                        LineMark(
                            x: .value("Дата", entry.date),
                            y: .value(metric.name, entry.value)
                        )
                        .foregroundStyle(.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Дата", entry.date),
                            y: .value(metric.name, entry.value)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                let formatted = val.truncatingRemainder(dividingBy: 1) == 0
                                    ? "\(Int(val))"
                                    : String(format: "%.1f", val)
                                Text(formatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)

                Divider()
            } else {
                Text(filteredEntries.isEmpty ? "Добавьте первую запись" : "Недостаточно данных для графика")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(20)

                Divider()
            }

            // Кнопка-ссылка на полный список
            NavigationLink {
                CustomMetricListView(metric: metric)
            } label: {
                HStack {
                    Spacer()
                    Text("Все измерения →")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.separator), lineWidth: 0.5))
        .sheet(isPresented: $isShowingAddEntry) {
            AddCustomMetricEntrySheet(metric: metric)
                .presentationDetents([.medium, .large])
        }
    }
}
