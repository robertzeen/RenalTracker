//
//  BloodPressureCardView.swift
//  RenalTracker
//

import SwiftUI
import Charts

struct BloodPressureCardView: View {
    let latestRecord: BloodPressure?
    let chartData: [BloodPressure]
    let yDomain: ClosedRange<Double>?
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ДАВЛЕНИЕ И ПУЛЬС")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let last = latestRecord {
                        Text("Последнее: \(last.systolic)/\(last.diastolic), пульс \(last.pulse)")
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
                            y: .value("Сист.", record.systolic),
                            series: .value("Тип", "systolic")
                        )
                        .foregroundStyle(Color.red)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Сист.", record.systolic)
                        )
                        .foregroundStyle(Color.red)
                        .symbolSize(40)
                    }

                    ForEach(chartData) { record in
                        LineMark(
                            x: .value("Дата", record.date),
                            y: .value("Диаст.", record.diastolic),
                            series: .value("Тип", "diastolic")
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Диаст.", record.diastolic)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: yDomain ?? 60...180)
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

            Divider()

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Сист.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("Диаст.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink {
                    BloodPressureListView()
                } label: {
                    Text("Все измерения →")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }
}
