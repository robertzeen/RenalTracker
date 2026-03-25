//
//  MedicationsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import PDFKit
import UIKit

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

    private var calendar: Calendar { Calendar.current }

    private var todayStart: Date { calendar.startOfDay(for: Date()) }

    private var todayEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(24 * 60 * 60)
    }

    private var todayWeekday: Int {
        calendar.component(.weekday, from: Date())
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

    /// Активные лекарства, которые должны быть приняты сегодня
    private var todaysMedications: [Medication] {
        medications.filter { $0.isActive && $0.daysOfWeek.contains(todayWeekday) }
    }

    private var totalCount: Int { todaysMedications.count }

    private var takenCount: Int {
        todaysMedications.filter { intakeForToday(medication: $0)?.isTaken == true }.count
    }

    /// Группы лекарств по времени приёма (от раннего к позднему)
    private var todayScheduleGroups: [(time: Date, medications: [Medication])] {
        let grouped = Dictionary(grouping: todaysMedications) { med -> Date in
            let comps = calendar.dateComponents([.hour, .minute], from: med.time)
            return calendar.date(from: comps) ?? med.time
        }
        return grouped
            .map { key, value in
                let sortedMeds = value.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return (time: key, medications: sortedMeds)
            }
            .sorted { $0.time < $1.time }
    }

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if medications.isEmpty {
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
                    } else {
                        List {
                            if !todaysMedications.isEmpty {
                                Section {
                                    MedicationTodayProgressCard(
                                        takenCount: takenCount,
                                        totalCount: totalCount
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                }
                            }

                            // Расписание на сегодня
                            if todayScheduleGroups.isEmpty {
                                Section {
                                    Text(MedicationScheduleCopy.noScheduledToday)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                ForEach(todayScheduleGroups, id: \.time) { group in
                                    Section {
                                        ForEach(group.medications) { med in
                                            let isTaken = intakeForToday(medication: med)?.isTaken == true
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
        .onAppear {
            NotificationManager.shared.rescheduleMedicationNotifications(for: medications)
        }
        .onChange(of: medications) { _, newMeds in
            NotificationManager.shared.rescheduleMedicationNotifications(for: newMeds)
        }
    }

    // MARK: - Helpers

    private func intakeForToday(medication: Medication) -> MedicationIntake? {
        intakes.first { intake in
            intake.medication == medication &&
            intake.date >= todayStart &&
            intake.date < todayEnd
        }
    }

    private func toggleTaken(for medication: Medication) {
        if let existing = intakeForToday(medication: medication) {
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

    private func generateMedicationsPDFData(meds: [Medication], patientName: String) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "RenalTracker",
            kCGPDFContextAuthor as String: "RenalTracker"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            _ = context.cgContext

            let margin: CGFloat = 40
            var y: CGFloat = 40

            let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let tableHeaderFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let tableCellFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let footerFont = UIFont.systemFont(ofSize: 9, weight: .regular)

            let paragraphLeft = NSMutableParagraphStyle()
            paragraphLeft.alignment = .left

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            ("Список принимаемых лекарств" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += titleFont.lineHeight + 8

            let subtitleAttrs: [NSAttributedString.Key: Any] = [.font: subtitleFont, .paragraphStyle: paragraphLeft]
            let formattedNow = DateFormatter.russianDateTime.string(from: Date())
            ("Сформировано: \(formattedNow)" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += subtitleFont.lineHeight + 4
            ("Пациент: \(patientName)" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += subtitleFont.lineHeight + 20

            let tableWidth = pageRect.width - margin * 2
            let col1Width = tableWidth * 0.45
            let col2Width = tableWidth * 0.25
            let col3Width = tableWidth * 0.30
            let rowHeight: CGFloat = 22

            let headerAttrs: [NSAttributedString.Key: Any] = [.font: tableHeaderFont, .paragraphStyle: paragraphLeft]
            let headerY = y + (rowHeight - tableHeaderFont.lineHeight) / 2
            ("Препарат" as NSString).draw(in: CGRect(x: margin + 4, y: headerY, width: col1Width - 8, height: tableHeaderFont.lineHeight), withAttributes: headerAttrs)
            ("Дозировка" as NSString).draw(in: CGRect(x: margin + col1Width + 4, y: headerY, width: col2Width - 8, height: tableHeaderFont.lineHeight), withAttributes: headerAttrs)
            ("Время приёма" as NSString).draw(in: CGRect(x: margin + col1Width + col2Width + 4, y: headerY, width: col3Width - 8, height: tableHeaderFont.lineHeight), withAttributes: headerAttrs)
            y += rowHeight

            let cellAttrs: [NSAttributedString.Key: Any] = [.font: tableCellFont, .paragraphStyle: paragraphLeft]
            let timeFormatter = DateFormatter.russianTime

            for med in meds {
                if y + rowHeight + 40 > pageRect.height {
                    context.beginPage()
                    y = 40
                }
                let cellY = y + (rowHeight - tableCellFont.lineHeight) / 2
                let dosage = med.formattedDosage.isEmpty ? "—" : med.formattedDosage
                (med.name as NSString).draw(in: CGRect(x: margin + 4, y: cellY, width: col1Width - 8, height: tableCellFont.lineHeight), withAttributes: cellAttrs)
                (dosage as NSString).draw(in: CGRect(x: margin + col1Width + 4, y: cellY, width: col2Width - 8, height: tableCellFont.lineHeight), withAttributes: cellAttrs)
                (timeFormatter.string(from: med.time) as NSString).draw(in: CGRect(x: margin + col1Width + col2Width + 4, y: cellY, width: col3Width - 8, height: tableCellFont.lineHeight), withAttributes: cellAttrs)
                y += rowHeight
            }

            y += 24
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .paragraphStyle: paragraphLeft, .foregroundColor: UIColor.secondaryLabel]
            ("Данные сформированы приложением RenalTracker" as NSString).draw(
                at: CGPoint(x: margin, y: min(y, pageRect.height - footerFont.lineHeight - 20)),
                withAttributes: footerAttrs
            )
        }

        let pdfDocument = PDFDocument(data: data)
        return pdfDocument?.dataRepresentation() ?? data
    }

    private func generatePDFFileURL(from data: Data) throws -> URL {
        let datePart = DateFormatter.fileDate.string(from: Date())
        let fileName = "Medications-\(datePart).pdf"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func generateAndSharePDF() async {
        let snapshot = await MainActor.run { () -> ([Medication], String) in
            (activeMedicationsSortedByTime, patientDisplayName)
        }
        let (meds, patient) = snapshot
        guard !meds.isEmpty else { return }

        let dataOpt = await Task.detached(priority: .userInitiated) {
            generateMedicationsPDFData(meds: meds, patientName: patient)
        }.value

        guard let data = dataOpt else { return }

        let fileURL: URL
        do {
            fileURL = try generatePDFFileURL(from: data)
        } catch {
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

    private struct WeekdayOption: Identifiable {
        let id: Int
        let shortTitle: String
    }

    private let weekdayOptions: [WeekdayOption] = [
        .init(id: 2, shortTitle: "Пн"),
        .init(id: 3, shortTitle: "Вт"),
        .init(id: 4, shortTitle: "Ср"),
        .init(id: 5, shortTitle: "Чт"),
        .init(id: 6, shortTitle: "Пт"),
        .init(id: 7, shortTitle: "Сб"),
        .init(id: 1, shortTitle: "Вс")
    ]

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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ForEach(weekdayOptions) { option in
                                let isSelected = selectedDays.contains(option.id)
                                Button { toggleDay(option.id) } label: {
                                    Text(option.shortTitle)
                                        .font(.subheadline)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        let allDays = Set(weekdayOptions.map { $0.id })
                        let isEveryday = selectedDays == allDays

                        Button {
                            selectedDays = isEveryday ? [] : allDays
                        } label: {
                            Text("Ежедневно")
                                .font(.subheadline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isEveryday ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                )
                        }
                        .buttonStyle(.plain)

                        if selectedDays.isEmpty {
                            Text("Выберите хотя бы один день.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

    private func toggleDay(_ weekday: Int) {
        if selectedDays.contains(weekday) {
            selectedDays.remove(weekday)
        } else {
            selectedDays.insert(weekday)
        }
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

    private struct WeekdayOption: Identifiable {
        let id: Int
        let shortTitle: String
    }

    private let weekdayOptions: [WeekdayOption] = [
        .init(id: 2, shortTitle: "Пн"),
        .init(id: 3, shortTitle: "Вт"),
        .init(id: 4, shortTitle: "Ср"),
        .init(id: 5, shortTitle: "Чт"),
        .init(id: 6, shortTitle: "Пт"),
        .init(id: 7, shortTitle: "Сб"),
        .init(id: 1, shortTitle: "Вс")
    ]

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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ForEach(weekdayOptions) { option in
                                let isSelected = selectedDays.contains(option.id)
                                Button { toggleDay(option.id) } label: {
                                    Text(option.shortTitle)
                                        .font(.subheadline)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        let allDays = Set(weekdayOptions.map { $0.id })
                        let isEveryday = selectedDays == allDays

                        Button {
                            selectedDays = isEveryday ? [] : allDays
                        } label: {
                            Text("Ежедневно")
                                .font(.subheadline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(isEveryday ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                                )
                        }
                        .buttonStyle(.plain)

                        if selectedDays.isEmpty {
                            Text("Выберите хотя бы один день.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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

    private func toggleDay(_ weekday: Int) {
        if selectedDays.contains(weekday) {
            selectedDays.remove(weekday)
        } else {
            selectedDays.insert(weekday)
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
