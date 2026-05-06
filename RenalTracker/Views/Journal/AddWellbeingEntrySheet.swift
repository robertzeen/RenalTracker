//
//  AddWellbeingEntrySheet.swift
//  RenalTracker
//
//  Sheet для добавления записи самочувствия.
//  Ползунок 1-5 + сетка симптомов из каталога + кастомные.
//

import SwiftUI
import SwiftData

struct AddWellbeingEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var wellbeing: Double = 3
    @State private var selectedSymptoms: Set<String> = []
    @State private var isShowingAddSymptom = false
    @State private var newSymptomName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Самочувствие

                    VStack(alignment: .leading, spacing: 12) {
                        Text("САМОЧУВСТВИЕ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        VStack(spacing: 8) {
                            // Ползунок
                            HStack {
                                Text(wellbeingEmoji)
                                    .font(.system(size: 32))
                                Spacer()
                                Text(wellbeingLabel)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }

                            Slider(value: $wellbeing, in: 1...5, step: 1)
                                .tint(.blue)

                            HStack {
                                Text("плохо")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Text("хорошо")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 0.5))
                    }

                    // MARK: - Симптомы

                    VStack(alignment: .leading, spacing: 12) {
                        Text("СИМПТОМЫ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 10) {
                            symptomChipsGrid

                            // Кнопка добавления кастомного симптома
                            Button {
                                isShowingAddSymptom = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Добавить симптом")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(.blue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(.separator), lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .navigationTitle("Самочувствие")
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
                }
            }
            .alert("Добавить симптом", isPresented: $isShowingAddSymptom) {
                TextField("Название симптома", text: $newSymptomName)
                Button("Добавить") {
                    let trimmed = newSymptomName.trimmingCharacters(in: .whitespaces)
                    if SymptomCatalog.addCustom(trimmed) {
                        selectedSymptoms.insert(trimmed)
                    }
                    newSymptomName = ""
                }
                Button("Отмена", role: .cancel) {
                    newSymptomName = ""
                }
            }
        }
    }

    // MARK: - Chips Grid

    @ViewBuilder
    private var symptomChipsGrid: some View {
            FlowLayout(spacing: 8) {
                ForEach(SymptomCatalog.all, id: \.self) { symptom in
                    let isSelected = selectedSymptoms.contains(symptom)

                    Button {
                        if isSelected {
                            selectedSymptoms.remove(symptom)
                        } else {
                            selectedSymptoms.insert(symptom)
                        }
                    } label: {
                        Text(symptom)
                            .font(.system(size: 14))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }

    // MARK: - Wellbeing helpers

    private var wellbeingInt: Int {
        Int(wellbeing)
    }

    private var wellbeingEmoji: String {
        switch wellbeingInt {
        case 1: return "😣"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }

    private var wellbeingLabel: String {
        switch wellbeingInt {
        case 1: return "Очень плохо"
        case 2: return "Плохо"
        case 3: return "Нормально"
        case 4: return "Хорошо"
        case 5: return "Отлично"
        default: return ""
        }
    }

    // MARK: - Save

    private func save() {
        let entry = WellbeingEntry(
            date: Date(),
            wellbeing: wellbeingInt,
            symptoms: Array(selectedSymptoms)
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

#Preview {
    AddWellbeingEntrySheet()
        .modelContainer(for: [WellbeingEntry.self], inMemory: true)
}
