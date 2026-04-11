//
//  AddCustomMetricEntrySheet.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct AddCustomMetricEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let metric: CustomMetric

    @State private var valueText = ""
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    private var canSave: Bool {
        let normalized = valueText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Значение
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: metric.icon)
                                .foregroundStyle(.blue)
                            Text(metric.name.uppercased())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            TextField("0", text: $valueText)
                                .font(.system(size: 15, weight: .medium))
                                .keyboardType(.decimalPad)
                            Text(metric.unit)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    // Дата и время
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ДАТА И ВРЕМЯ")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(DateFormatter.russianDateTime.string(from: selectedDate))
                                    .font(.system(size: 15, weight: .medium))
                            }
                            Spacer()
                            Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                        .onTapGesture { showDatePicker.toggle() }

                        if showDatePicker {
                            Divider()
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                in: ...Date(),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .padding(.horizontal, 8)
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Добавить запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                        dismiss()
                    }
                    .fontWeight(.medium)
                    .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private func save() {
        let normalized = valueText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return }
        let entry = CustomMetricEntry(value: value, date: selectedDate, metric: metric)
        modelContext.insert(entry)
        metric.entries.append(entry)
        try? modelContext.save()
    }
}
