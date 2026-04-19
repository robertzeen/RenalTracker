//
//  SettingsCustomMetricsSection.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct SettingsCustomMetricsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomMetric.sortOrder) private var metrics: [CustomMetric]
    @Binding var isShowingAddCustomMetric: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ДОПОЛНИТЕЛЬНЫЕ ПОКАЗАТЕЛИ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            // Предустановленные метрики
            VStack(spacing: 0) {
                ForEach(Array(predefinedMetrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 { Divider().padding(.leading, 56) }
                    HStack {
                        Image(systemName: metric.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.name)
                                .font(.system(size: 15, weight: .medium))
                            Text(metric.unit)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { metric.isActive },
                            set: { newValue in
                                metric.isActive = newValue
                                try? modelContext.save()
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(14)
                }

                if !predefinedMetrics.isEmpty {
                    Divider().padding(.leading, 14)
                }

                // Кнопка добавления своей метрики
                Button {
                    isShowingAddCustomMetric = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Добавить свою метрику")
                            .font(.system(size: 15))
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

            // Кастомные метрики пользователя
            if !customMetrics.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(customMetrics.enumerated()), id: \.element.id) { index, metric in
                        if index > 0 { Divider().padding(.leading, 56) }
                        HStack {
                            Image(systemName: metric.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.name)
                                    .font(.system(size: 15, weight: .medium))
                                Text(metric.unit)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { metric.isActive },
                                set: { newValue in
                                    metric.isActive = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .labelsHidden()

                            Button {
                                deleteCustomMetric(metric)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(14)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 0.5))
            }
        }
        .onAppear {
            initializePredefinedMetrics()
        }
    }

    // MARK: - Helpers

    private var predefinedMetrics: [CustomMetric] {
        metrics.filter { !$0.isCustom }
    }

    private var customMetrics: [CustomMetric] {
        metrics.filter { $0.isCustom }
    }

    private func initializePredefinedMetrics() {
        guard metrics.isEmpty else { return }
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

    private func deleteCustomMetric(_ metric: CustomMetric) {
        modelContext.delete(metric)
        try? modelContext.save()
    }
}
