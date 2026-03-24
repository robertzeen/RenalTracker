//
//  AddTrackedLabTestSheet.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct AddTrackedLabTestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var existingTests: [TrackedLabTest]

    var onNavigateToExisting: (TrackedLabTest) -> Void

    @State private var useCustomName: Bool = false
    @State private var selectedDefinition: LabTestDefinition?
    @State private var customName: String = ""
    @State private var customUnit: String = ""
    @State private var customReferenceMin: String = ""
    @State private var customReferenceMax: String = ""

    @State private var duplicateTest: TrackedLabTest?
    @State private var showDuplicateAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Режим", selection: $useCustomName) {
                        Text("Выбрать из списка").tag(false)
                        Text("Свой анализ").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: useCustomName) { _, isCustom in
                        if isCustom {
                            selectedDefinition = nil
                        } else {
                            customName = ""
                            customUnit = ""
                            customReferenceMin = ""
                            customReferenceMax = ""
                        }
                    }
                }

                if !useCustomName {
                    Section("Стандартные анализы") {
                        Picker("Анализ", selection: $selectedDefinition) {
                            Text("Не выбран").tag(Optional<LabTestDefinition>.none)
                            ForEach(LabTestCatalog.predefined) { def in
                                Text(def.name).tag(Optional(def))
                            }
                        }
                    }
                } else {
                    Section("Свой анализ") {
                        TextField("Название анализа", text: $customName)
                        TextField("Единица измерения", text: $customUnit)
                            .textInputAutocapitalization(.never)
                        TextField("Нижняя граница (необязательно)", text: $customReferenceMin)
                            .keyboardType(.decimalPad)
                        TextField("Верхняя граница (необязательно)", text: $customReferenceMax)
                            .keyboardType(.decimalPad)
                    }
                }
            }
            .navigationTitle("Новый анализ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { attemptSave() }
                        .disabled(!canSave)
                }
            }
            .alert("Анализ уже существует", isPresented: $showDuplicateAlert, presenting: duplicateTest) { existing in
                Button("Перейти к анализу") {
                    dismiss()
                    onNavigateToExisting(existing)
                }
                Button("Отмена", role: .cancel) { }
            } message: { existing in
                Text("«\(existing.name)» уже добавлен в список отслеживаемых анализов. Вы можете добавить новый результат в существующий анализ.")
            }
        }
    }

    private var canSave: Bool {
        useCustomName
            ? !customName.trimmingCharacters(in: .whitespaces).isEmpty
            : selectedDefinition != nil
    }

    private func pendingName() -> String {
        useCustomName
            ? customName.trimmingCharacters(in: .whitespaces)
            : selectedDefinition?.name ?? ""
    }

    private func attemptSave() {
        let name = pendingName()
        if let existing = existingTests.first(where: { $0.name.lowercased() == name.lowercased() }) {
            duplicateTest = existing
            showDuplicateAlert = true
            return
        }
        save()
    }

    private func save() {
        if let def = selectedDefinition, !useCustomName {
            let test = TrackedLabTest(
                name: def.name, unit: def.unit,
                referenceMin: def.referenceMin, referenceMax: def.referenceMax,
                isCustom: false
            )
            modelContext.insert(test)
        } else {
            let min  = Double(customReferenceMin.replacingOccurrences(of: ",", with: "."))
            let max  = Double(customReferenceMax.replacingOccurrences(of: ",", with: "."))
            let test = TrackedLabTest(
                name: customName.trimmingCharacters(in: .whitespaces),
                unit: customUnit.trimmingCharacters(in: .whitespaces),
                referenceMin: min, referenceMax: max,
                isCustom: true
            )
            modelContext.insert(test)
        }
        try? modelContext.save()
        dismiss()
    }
}
