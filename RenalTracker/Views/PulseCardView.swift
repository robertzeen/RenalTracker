//
//  PulseCardView.swift
//  RenalTracker
//

import SwiftUI
import Charts

struct PulseCardView: View {
    let latestRecord: BloodPressure?
    let chartData: [BloodPressure]
    let yDomain: ClosedRange<Double>?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ПУЛЬС")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let last = latestRecord {
                        Text("Последнее: \(last.pulse) уд/мин")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
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
                            y: .value("Пульс", record.pulse)
                        )
                        .foregroundStyle(Color.green)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Пульс", record.pulse)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: yDomain ?? 40...120)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text("\(val)")
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
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }
}
