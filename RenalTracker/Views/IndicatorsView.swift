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

    @Query(sort: \CustomMetric.sortOrder)
    private var allMetrics: [CustomMetric]

    private var activeMetrics: [CustomMetric] {
        allMetrics.filter { $0.isActive }
    }

    @State private var chartPeriod: ChartPeriod = .days7
    @State private var isShowingAddBloodPressure = false
    @State private var isShowingAddWeight = false
    @State private var isEditing = false
    @State private var isShowingAddMetricSheet = false
    @State private var metricToDelete: CustomMetric?
    @State private var isShowingDeleteConfirmation = false

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
            Group {
                if isEditing {
                    editingMode
                } else {
                    normalMode
                }
            }
            .navigationTitle("Метрики")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isEditing {
                        Button("Готово") {
                            isEditing = false
                        }
                        .fontWeight(.medium)
                    } else {
                        Button {
                            isEditing = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(.secondarySystemBackground))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "gearshape")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Управление метриками")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddBloodPressure) {
            AddBloodPressureSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingAddWeight) {
            AddWeightSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingAddMetricSheet) {
            AddMetricSheet()
        }
        .alert("Удалить метрику?", isPresented: $isShowingDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                if let metric = metricToDelete {
                    modelContext.delete(metric)
                    try? modelContext.save()
                }
                metricToDelete = nil
            }
            Button("Отмена", role: .cancel) {
                metricToDelete = nil
            }
        } message: {
            if let metric = metricToDelete {
                Text("«\(metric.name)» и все записи будут удалены. Это действие нельзя отменить.")
            }
        }
        .onAppear {
            initializePredefinedMetricsIfNeeded()
            migrateLegacySortOrders()
        }
    }

    // MARK: - Normal mode

    @ViewBuilder
    private var normalMode: some View {
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

                ForEach(activeMetrics) { metric in
                    CustomMetricCardView(metric: metric, chartPeriod: chartPeriod)
                }

                Button {
                    isShowingAddMetricSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Добавить метрику")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Editing mode

    @ViewBuilder
    private var editingMode: some View {
        List {
            Section {
                ForEach(activeMetrics) { metric in
                    HStack(spacing: 12) {
                        Image(systemName: metric.icon)
                            .font(.system(size: 15))
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        Text(metric.name)
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                        if metric.isCustom {
                            Button {
                                metricToDelete = metric
                                isShowingDeleteConfirmation = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove { indices, newOffset in
                    moveMetric(indices: indices, newOffset: newOffset)
                }
            } header: {
                Text("ПОРЯДОК ОТОБРАЖЕНИЯ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } footer: {
                Text("Перетащите строки, чтобы изменить порядок. Свои метрики можно удалить кнопкой —.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    isShowingAddMetricSheet = true
                } label: {
                    Label("Управление метриками каталога", systemImage: "square.grid.2x2")
                        .foregroundStyle(.blue)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Helpers

    private func moveMetric(indices: IndexSet, newOffset: Int) {
        var metrics = activeMetrics
        metrics.move(fromOffsets: indices, toOffset: newOffset)
        for (i, metric) in metrics.enumerated() {
            metric.sortOrder = i + 1
        }
        try? modelContext.save()
    }

    /// Создаёт предустановленные метрики из CustomMetricCatalog при первом запуске.
    /// Идемпотентна — повторные вызовы ничего не делают, если каталог уже инициализирован.
    private func initializePredefinedMetricsIfNeeded() {
        let hasPredefinedMetrics = allMetrics.contains { !$0.isCustom }
        guard !hasPredefinedMetrics else { return }

        for definition in CustomMetricCatalog.predefined {
            let metric = CustomMetric(
                name: definition.name,
                unit: definition.unit,
                icon: definition.icon,
                isActive: false,
                isCustom: false,
                sortOrder: definition.sortOrder
            )
            modelContext.insert(metric)
        }
        try? modelContext.save()
    }

    /// Миграция исторических данных: чинит sortOrder для метрик, созданных до правильной
    /// логики назначения порядка. Будет ненужной, когда у всех пользователей данные уже
    /// мигрированы — можно удалить через 6+ месяцев после релиза.
    private func migrateLegacySortOrders() {
        var changed = false

        // Нормализация sortOrder для предустановленных метрик
        for definition in CustomMetricCatalog.predefined {
            if let metric = allMetrics.first(where: { $0.name == definition.name && !$0.isCustom }),
               metric.sortOrder != definition.sortOrder {
                metric.sortOrder = definition.sortOrder
                changed = true
            }
        }

        // Custom-метрики с placeholder sortOrder == 100 (legacy bug в AddCustomMetricView)
        let maxPredefinedOrder = CustomMetricCatalog.predefined.map(\.sortOrder).max() ?? 0
        let customMetrics = allMetrics.filter { $0.isCustom }
        for (i, metric) in customMetrics.enumerated() where metric.sortOrder == 100 {
            metric.sortOrder = maxPredefinedOrder + i + 1
            changed = true
        }

        if changed {
            try? modelContext.save()
        }
    }
}

#Preview {
    IndicatorsView()
        .modelContainer(for: [BloodPressure.self, Weight.self, CustomMetric.self, CustomMetricEntry.self], inMemory: true)
}
