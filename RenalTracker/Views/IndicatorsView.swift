//
//  IndicatorsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import Charts

// Период для графиков (общий для всех)
enum ChartPeriod: String, CaseIterable {
    case days7  = "7 дней"
    case days30 = "30 дней"
    case all    = "Всё время"

    var title: String { rawValue }
}

struct IndicatorsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BloodPressure.date, order: .reverse)
    private var bloodPressureRecords: [BloodPressure]

    @Query(sort: \Weight.date, order: .reverse)
    private var weightRecords: [Weight]

    @State private var chartPeriod: ChartPeriod = .days7
    @State private var isShowingAddBloodPressure = false
    @State private var isShowingAddWeight = false

    // MARK: - Filtered chart data

    private var recentBloodPressureChart: [BloodPressure] {
        switch chartPeriod {
        case .days7:  return bloodPressureRecords.filter { $0.date >= Date().addingTimeInterval(-7 * 24 * 3600) }
        case .days30: return bloodPressureRecords.filter { $0.date >= Date().addingTimeInterval(-30 * 24 * 3600) }
        case .all:    return bloodPressureRecords
        }
    }

    private var recentWeightChart: [Weight] {
        switch chartPeriod {
        case .days7:  return weightRecords.filter { $0.date >= Date().addingTimeInterval(-7 * 24 * 3600) }
        case .days30: return weightRecords.filter { $0.date >= Date().addingTimeInterval(-30 * 24 * 3600) }
        case .all:    return weightRecords
        }
    }

    // MARK: - Y-axis domains

    private var bloodPressureYDomain: ClosedRange<Double>? {
        guard recentBloodPressureChart.count >= 2 else { return nil }
        let values = recentBloodPressureChart.flatMap { [Double($0.systolic), Double($0.diastolic)] }
        guard let minVal = values.min(), let maxVal = values.max() else { return nil }
        return max(0, minVal - 10)...maxVal + 10
    }

    private var pulseYDomain: ClosedRange<Double>? {
        guard recentBloodPressureChart.count >= 2 else { return nil }
        let values = recentBloodPressureChart.map { Double($0.pulse) }
        guard let minVal = values.min(), let maxVal = values.max() else { return nil }
        return max(0, minVal - 5)...maxVal + 5
    }

    private var weightYDomain: ClosedRange<Double>? {
        guard recentWeightChart.count >= 2 else { return nil }
        let values = recentWeightChart.map { $0.valueKg }
        guard let minVal = values.min(), let maxVal = values.max() else { return nil }
        return max(0, minVal - 1)...maxVal + 1
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Период", selection: $chartPeriod) {
                        ForEach(ChartPeriod.allCases, id: \.rawValue) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    BloodPressureCardView(
                        latestRecord: bloodPressureRecords.first,
                        chartData: recentBloodPressureChart,
                        yDomain: bloodPressureYDomain,
                        onAdd: { isShowingAddBloodPressure = true }
                    )

                    PulseCardView(
                        latestRecord: bloodPressureRecords.first,
                        chartData: recentBloodPressureChart,
                        yDomain: pulseYDomain
                    )

                    WeightCardView(
                        latestRecord: weightRecords.first,
                        chartData: recentWeightChart,
                        yDomain: weightYDomain,
                        onAdd: { isShowingAddWeight = true }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Показатели")
        }
        .sheet(isPresented: $isShowingAddBloodPressure) {
            AddBloodPressureSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingAddWeight) {
            AddWeightSheet()
                .presentationDetents([.medium, .large])
        }
    }
}

#Preview {
    IndicatorsView()
        .modelContainer(for: [BloodPressure.self, Weight.self], inMemory: true)
}
