//
//  AddMetricSheet.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct AddMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CustomMetric.sortOrder)
    private var allMetrics: [CustomMetric]

    @State private var isShowingAddCustom = false

    private var customMetrics: [CustomMetric] {
        allMetrics.filter { $0.isCustom }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Из каталога") {
                    ForEach(CustomMetricCatalog.predefined, id: \.name) { definition in
                        let existing = allMetrics.first { $0.name == definition.name && !$0.isCustom }
                        HStack {
                            Image(systemName: definition.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text(definition.name)
                                .font(.system(size: 15))
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { existing?.isActive ?? false },
                                set: { on in toggleCatalog(definition: definition, existing: existing, on: on) }
                            ))
                            .labelsHidden()
                        }
                    }
                }

                if !customMetrics.isEmpty {
                    Section("Мои метрики") {
                        ForEach(customMetrics) { metric in
                            HStack {
                                Image(systemName: metric.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.blue)
                                    .frame(width: 28)
                                Text(metric.name)
                                    .font(.system(size: 15))
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { metric.isActive },
                                    set: { on in
                                        metric.isActive = on
                                        try? modelContext.save()
                                    }
                                ))
                                .labelsHidden()
                            }
                        }
                    }
                }

                Section {
                    Button {
                        isShowingAddCustom = true
                    } label: {
                        Label("Добавить свою метрику", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Управление метриками")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
        .sheet(isPresented: $isShowingAddCustom) {
            AddCustomMetricView()
        }
    }

    private func toggleCatalog(definition: CustomMetricDefinition, existing: CustomMetric?, on: Bool) {
        if let metric = existing {
            metric.isActive = on
        } else if on {
            let metric = CustomMetric(
                name: definition.name,
                unit: definition.unit,
                icon: definition.icon,
                isActive: true,
                isCustom: false,
                sortOrder: definition.sortOrder
            )
            modelContext.insert(metric)
        }
        try? modelContext.save()
    }
}
