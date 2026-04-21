//
//  MedicationsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct MedicationsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]

    @Query(sort: \Medication.name, order: .forward)
    private var medications: [Medication]

    @Query(sort: \MedicationIntake.date, order: .forward)
    private var intakes: [MedicationIntake]

    @State private var isShowingAddMedication = false
    @State private var medicationToEdit: Medication?
    @State private var medicationToDelete: Medication?
    @State private var isShowingDeleteConfirmation = false

    @State private var exportFileURL: URL?
    @State private var isShowingExportSheet = false
    @State private var isGeneratingPDF = false
    @State private var isShowingExportErrorAlert = false

    @AppStorage(AppStorageKeys.notificationsEnabled) private var notificationsEnabled = true
    @AppStorage(AppStorageKeys.criticalNotificationsEnabled) private var criticalNotificationsEnabled = false

    private var scheduleCalculator: MedicationScheduleCalculator {
        MedicationScheduleCalculator(medications: medications, intakes: intakes)
    }

    private var activeMedicationsSortedByTime: [Medication] {
        medications
            .filter { $0.isActive }
            .sorted { $0.time < $1.time }
    }

    private var patientDisplayName: String {
        guard let profile = profiles.first else { return "не указан" }
        let name = profile.name.trimmingCharacters(in: .whitespaces)
        let last = profile.lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !name.isEmpty && !last.isEmpty {
            return "\(name) \(last)"
        } else if !name.isEmpty {
            return name
        } else if !last.isEmpty {
            return last
        } else {
            return "не указан"
        }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if medications.isEmpty {
                        emptyStateView
                    } else {
                        List {
                            if !scheduleCalculator.todaysMedications.isEmpty {
                                Section {
                                    MedicationTodayProgressCard(
                                        takenCount: scheduleCalculator.takenCount,
                                        totalCount: scheduleCalculator.totalCount
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                }
                            }

                            // Расписание на сегодня
                            if scheduleCalculator.todayScheduleGroups.isEmpty {
                                Section {
                                    Text(MedicationScheduleCopy.noScheduledToday)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                ForEach(scheduleCalculator.todayScheduleGroups, id: \.time) { group in
                                    Section {
                                        ForEach(group.medications) { med in
                                            medicationRow(med: med)
                                        }
                                    } header: {
                                        HStack {
                                            Text(MedicationScheduleFormat.timeString(for: group.time))
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.secondary)
                                            Rectangle()
                                                .fill(Color(.separator))
                                                .frame(height: 0.5)
                                        }
                                        .padding(.horizontal, 0)
                                        .textCase(nil)
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
//                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle("Лекарства")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isGeneratingPDF = true
                            Task {
                                await generateAndSharePDF()
                                await MainActor.run { isGeneratingPDF = false }
                            }
                        } label: {
                            ZStack {
                                Circle().fill(Color(.secondarySystemBackground)).frame(width: 32, height: 32)
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Экспорт списка лекарств")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingAddMedication = true
                        } label: {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.15)).frame(width: 32, height: 32)
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .accessibilityLabel("Добавить принимаемые лекарства")
                    }
                }
            }

            // Оверлей генерации PDF
            if isGeneratingPDF {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Формируем PDF...")
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(Color(.systemGray2).opacity(0.9))
                    .cornerRadius(16)
                }
            }
        }
        .sheet(isPresented: $isShowingAddMedication) {
            AddMedicationSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $medicationToEdit) { med in
            EditMedicationSheet(medication: med)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingExportSheet) {
            if let url = exportFileURL {
                ShareSheet(activityItems: [url])
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Формирование PDF...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .alert("Удалить лекарство?", isPresented: $isShowingDeleteConfirmation) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                if let med = medicationToDelete {
                    deleteMedication(med)
                }
                medicationToDelete = nil
            }
        } message: {
            if let med = medicationToDelete {
                Text("«\(med.name)» будет удалено из расписания. Это действие нельзя отменить.")
            }
        }
        .alert("Не удалось сформировать отчёт", isPresented: $isShowingExportErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Попробуйте ещё раз. Если ошибка повторится, обратитесь в поддержку.")
        }
        .onAppear {
            NotificationManager.shared.rescheduleMedicationNotifications(
                for: medications,
                enabled: notificationsEnabled,
                critical: criticalNotificationsEnabled
            )
        }
        .onChange(of: medications) { _, newMeds in
            NotificationManager.shared.rescheduleMedicationNotifications(
                for: newMeds,
                enabled: notificationsEnabled,
                critical: criticalNotificationsEnabled
            )
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Лекарства")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Добавьте принимаемые лекарства, чтобы видеть расписание приёма и отмечать выполненные дозы.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            Button("Добавить принимаемые лекарства") {
                isShowingAddMedication = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    @ViewBuilder
    private func medicationRow(med: Medication) -> some View {
        let isTaken = scheduleCalculator.isTaken(med)
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(med.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(MedicationScheduleFormat.dosageCaption(for: med))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(
                        isTaken ? Color.green : Color(.separator),
                        lineWidth: 1.5
                    )
                    .frame(width: 26, height: 26)
                if isTaken {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Circle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    toggleTaken(for: med)
                }
            }
            .accessibilityLabel(isTaken ? "Лекарство принято" : "Отметить приём")
            .accessibilityAddTraits(.isButton)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                medicationToDelete = med
                isShowingDeleteConfirmation = true
            } label: {
                Label("Удалить", systemImage: "trash")
            }
            Button {
                medicationToEdit = med
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
            .tint(.gray)
        }
    }

    private func toggleTaken(for medication: Medication) {
        if let existing = scheduleCalculator.intakeForToday(for: medication) {
            if existing.isTaken {
                modelContext.delete(existing)
            } else {
                existing.isTaken = true
            }
        } else {
            let intake = MedicationIntake(date: Date(), isTaken: true, medication: medication)
            modelContext.insert(intake)
        }
        try? modelContext.save()
    }

    private func deleteMedication(_ medication: Medication) {
        modelContext.delete(medication)
        try? modelContext.save()
    }

    // MARK: - PDF Export

    private func generateAndSharePDF() async {
        // Снимок ТОЛЬКО value-type данных на главном потоке — до Task.detached
        let snapshot = await MainActor.run { () -> ([MedicationsPDFExporter.Row], String) in
            let rows = activeMedicationsSortedByTime.map { med in
                MedicationsPDFExporter.Row(
                    name: med.name,
                    dosage: med.formattedDosage.isEmpty ? "—" : med.formattedDosage,
                    time: DateFormatter.russianTime.string(from: med.time)
                )
            }
            return (rows, patientDisplayName)
        }
        let (rows, patient) = snapshot
        guard !rows.isEmpty else { return }

        let dataOpt = await Task.detached(priority: .userInitiated) {
            MedicationsPDFExporter.generateData(rows: rows, patientName: patient)
        }.value

        guard let data = dataOpt else { return }

        let fileURL: URL
        do {
            fileURL = try MedicationsPDFExporter.fileURL(from: data)
        } catch {
            print("Failed to save medications PDF: \(error)")
            await MainActor.run {
                isShowingExportErrorAlert = true
            }
            return
        }

        await MainActor.run {
            exportFileURL = fileURL
            isShowingExportSheet = true
        }
    }
}

// MARK: - Добавление лекарства

private struct AddMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name: String = ""
    @State private var dosageAmountText: String = ""
    @State private var dosageUnit: String = ""
    @State private var selectedDays: Set<Int> = []
    @State private var time: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Лекарство") {
                    TextField("Наименование", text: $name)
                        .autocorrectionDisabled()
                    HStack {
                        TextField("Количество", text: $dosageAmountText)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                        TextField("Ед. изм. (мг, МЕ...)", text: $dosageUnit)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Дни приёма") {
                    WeekdayPickerView(selectedDays: $selectedDays)
                }

                Section("Время приёма") {
                    DatePicker("Время", selection: $time, displayedComponents: .hourAndMinute)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
            .navigationTitle("Новое лекарство")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !selectedDays.isEmpty
    }

    private func save() {
        let normalizedAmount = dosageAmountText.replacingOccurrences(of: ",", with: ".")
        let amount = Double(normalizedAmount)
        let med = Medication(
            name: name.trimmingCharacters(in: .whitespaces),
            dosageAmount: amount,
            dosageUnit: dosageUnit.trimmingCharacters(in: .whitespaces),
            daysOfWeek: Array(selectedDays),
            time: time,
            isActive: true
        )
        modelContext.insert(med)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Редактирование лекарства

private struct EditMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var medication: Medication

    @State private var dosageAmountText: String
    @State private var selectedDays: Set<Int>

    init(medication: Medication) {
        self.medication = medication
        _dosageAmountText = State(initialValue: medication.dosageAmount.map { String($0) } ?? "")
        _selectedDays = State(initialValue: Set(medication.daysOfWeek))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Лекарство") {
                    TextField("Наименование", text: $medication.name)
                        .autocorrectionDisabled()
                    HStack {
                        TextField("Количество", text: $dosageAmountText)
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                        TextField("Ед. изм. (мг, МЕ...)", text: $medication.dosageUnit)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                Section("Дни приёма") {
                    WeekdayPickerView(selectedDays: $selectedDays)
                }

                Section("Время приёма") {
                    DatePicker("Время", selection: $medication.time, displayedComponents: .hourAndMinute)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                }
            }
        }
    }

    private func save() {
        let normalizedAmount = dosageAmountText.replacingOccurrences(of: ",", with: ".")
        medication.dosageAmount = Double(normalizedAmount)
        medication.daysOfWeek = Array(selectedDays)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    MedicationsView()
        .modelContainer(for: [
            Medication.self,
            MedicationIntake.self
        ], inMemory: true)
}
