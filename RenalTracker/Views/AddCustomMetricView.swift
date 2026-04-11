//
//  AddCustomMetricView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct AddCustomMetricView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var unit = ""
    @State private var selectedIcon = "star.fill"

    private let icons = [
        "heart.fill", "flame.fill", "bolt.fill", "star.fill", "moon.fill",
        "sun.max.fill", "leaf.fill", "cross.fill", "figure.walk", "figure.run",
        "drop.fill", "thermometer", "waveform.path.ecg"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    // Название
                    VStack(alignment: .leading, spacing: 3) {
                        Text("НАЗВАНИЕ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Например: Калории", text: $name)
                            .font(.system(size: 15, weight: .medium))
                            .autocorrectionDisabled()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    // Единица измерения
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ЕДИНИЦА ИЗМЕРЕНИЯ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Например: ккал", text: $unit)
                            .font(.system(size: 15, weight: .medium))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    // Иконка
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ИКОНКА")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible()), count: 6),
                            spacing: 12
                        ) {
                            ForEach(icons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedIcon == icon ? .white : .blue)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            selectedIcon == icon
                                                ? Color.blue
                                                : Color.blue.opacity(0.1)
                                        )
                                        .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Новая метрика")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        save()
                    }
                    .fontWeight(.medium)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty
                              || unit.trimmingCharacters(in: .whitespaces).isEmpty)
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
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !trimmedUnit.isEmpty else { return }

        let metric = CustomMetric(
            name: trimmedName,
            unit: trimmedUnit,
            icon: selectedIcon,
            isActive: true,
            isCustom: true,
            sortOrder: 100
        )
        modelContext.insert(metric)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CustomMetric.self, configurations: config)
    return AddCustomMetricView()
        .modelContainer(container)
}
