//
//  WeightCardView.swift
//  RenalTracker
//

import SwiftUI
import Charts

struct WeightCardView: View {
    let latestRecord: Weight?
    let chartData: [Weight]
    let yDomain: ClosedRange<Double>?
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ВЕС")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let last = latestRecord {
                        let wVal = last.valueKg
                        let wStr = wVal.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(wVal))" : String(format: "%.1f", wVal)
                        Text("Последнее: \(wStr) кг")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { onAdd() } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(14)

            Divider()

            if chartData.count < 2 {
                Text("Недостаточно данных для графика")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(chartData) { record in
                        LineMark(
                            x: .value("Дата", record.date),
                            y: .value("Вес", record.valueKg)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Вес", record.valueKg)
                        )
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: yDomain ?? 40.0...120.0)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                let s = val.truncatingRemainder(dividingBy: 1) == 0
                                    ? "\(Int(val))" : String(format: "%.1f", val)
                                Text(s)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }

            Divider()

            NavigationLink {
                WeightListView()
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
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }
}
