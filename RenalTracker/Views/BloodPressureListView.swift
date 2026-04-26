//
//  BloodPressureListView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import Charts

// MARK: - BloodPressure Identifiable

extension BloodPressure: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

// MARK: - Blood Pressure List

struct BloodPressureListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BloodPressure.date, order: .reverse)
    private var records: [BloodPressure]

    @Query private var profiles: [UserProfile]

    @State private var recordToEdit: BloodPressure?
    @State private var recordToDelete: BloodPressure?
    @State private var showDeleteConfirmation = false
    @State private var showExportDialog = false
    @State private var pdfURL: URL?
    @State private var isSharePresented = false
    @State private var isShowingNoDataAlert = false
    @State private var isShowingExportErrorAlert = false

    private enum ExportPeriod {
        case days7, days30, all

        var title: String {
            switch self {
            case .days7: return "За 7 дней"
            case .days30: return "За 30 дней"
            case .all: return "Все данные"
            }
        }
    }

    private var patientDisplayName: String? {
        guard let profile = profiles.first else { return nil }
        var parts = [profile.name]
        if let last = profile.lastName { parts.append(last) }
        return parts.joined(separator: " ")
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: "ru_RU")
        return cal
    }

    private var groupedByMonth: [(date: Date, records: [BloodPressure])] {
        let grouped = Dictionary(grouping: records) { record -> Date in
            let comps = calendar.dateComponents([.year, .month], from: record.date)
            return calendar.date(from: comps) ?? record.date
        }
        return grouped
            .map { (key, value) in (date: key, records: value) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "Нет записей",
                    systemImage: "heart.text.square",
                    description: Text("Добавьте измерение давления на экране «Метрики»")
                )
            } else {
                List {
                    ForEach(groupedByMonth, id: \.date) { group in
                        Section {
                            ForEach(group.records) { record in
                                bpRow(record)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            recordToDelete = record
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            Text(DateFormatter.russianMonthYear.string(from: group.date).uppercased())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Давление и пульс")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !records.isEmpty {
                    Button { showExportDialog = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 32, height: 32)
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .sheet(item: $recordToEdit) { record in
            EditBloodPressureSheet(record: record)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Экспорт PDF", isPresented: $showExportDialog, titleVisibility: .visible) {
            Button(ExportPeriod.days7.title)  { exportPDF(for: .days7) }
            Button(ExportPeriod.days30.title) { exportPDF(for: .days30) }
            Button(ExportPeriod.all.title)    { exportPDF(for: .all) }
            Button("Отмена", role: .cancel) { }
        }
        .sheet(isPresented: $isSharePresented) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
        }
        .alert("Удалить измерение?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                if let r = recordToDelete {
                    modelContext.delete(r)
                    try? modelContext.save()
                }
                recordToDelete = nil
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Это действие нельзя отменить.")
        }
        .alert("Нет данных за выбранный период", isPresented: $isShowingNoDataAlert) {
            Button("Закрыть", role: .cancel) { }
        } message: {
            Text("Добавьте записи или выберите другой период для экспорта.")
        }
        .alert("Не удалось сформировать отчёт", isPresented: $isShowingExportErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Попробуйте ещё раз. Если ошибка повторится, обратитесь в поддержку.")
        }
    }

    @ViewBuilder
    private func bpRow(_ record: BloodPressure) -> some View {
        Button {
            recordToEdit = record
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(record.systolic)/\(record.diastolic) мм рт. ст., пульс \(record.pulse)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(DateFormatter.russianDateTime.string(from: record.date))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - PDF Export

    @MainActor
    private func exportPDF(for period: ExportPeriod) {
        let now = Date()
        let filteredRecords: [BloodPressure]
        let periodDescription: String

        switch period {
        case .days7:
            let from = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filteredRecords = records.filter { $0.date >= from }
            periodDescription = "за последние 7 дней"
        case .days30:
            let from = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filteredRecords = records.filter { $0.date >= from }
            periodDescription = "за последние 30 дней"
        case .all:
            filteredRecords = records
            periodDescription = "за весь период наблюдения"
        }

        guard !filteredRecords.isEmpty else { isShowingNoDataAlert = true; return }

        let snapshot = filteredRecords.map {
            BloodPressurePDFExporter.Record(
                date: $0.date,
                systolic: $0.systolic,
                diastolic: $0.diastolic,
                pulse: $0.pulse
            )
        }
        let data = BloodPressurePDFExporter.makeData(
            records: snapshot,
            periodDescription: periodDescription,
            patientName: patientDisplayName
        )
        do {
            pdfURL = try BloodPressurePDFExporter.fileURL(from: data)
            isSharePresented = true
        } catch {
            print("Failed to write PDF: \(error)")
            isShowingExportErrorAlert = true
        }
    }
}

// MARK: - Add Blood Pressure Sheet

struct AddBloodPressureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var systolic: Int = 120
    @State private var diastolic: Int = 80
    @State private var pulse: Int = 70
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false

    private let sysColor   = Color(red: 0.85, green: 0.25, blue: 0.25)
    private let diaColor   = Color(red: 0.25, green: 0.45, blue: 0.85)
    private let pulseColor = Color(red: 0.15, green: 0.65, blue: 0.35)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    bpCard
                    dateCard
                }
                .padding(16)
            }
            .navigationTitle("Давление и пульс")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction)  { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction)  { Button("Сохранить") { save() }.fontWeight(.medium) }
            }
        }
    }

    private var bpCard: some View {
        HStack(spacing: 8) {
            pickerColumn(label: "СИСТ.", color: sysColor, selection: $systolic, range: 60...250)
            pickerColumn(label: "ДИАСТ.", color: diaColor, selection: $diastolic, range: 40...150)
            pickerColumn(label: "ПУЛЬС", color: pulseColor, selection: $pulse, range: 30...250)
        }
    }

    private func pickerColumn(label: String, color: Color, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.12))
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var dateCard: some View {
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
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { showDatePicker.toggle() }

            if showDatePicker {
                Divider()
                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .padding(.horizontal, 8)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private func save() {
        let record = BloodPressure(systolic: systolic, diastolic: diastolic, pulse: pulse, date: selectedDate)
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Blood Pressure Sheet

private struct EditBloodPressureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let record: BloodPressure

    @State private var systolic: Int
    @State private var diastolic: Int
    @State private var pulse: Int
    @State private var selectedDate: Date
    @State private var showDatePicker = false

    private let sysColor   = Color(red: 0.85, green: 0.25, blue: 0.25)
    private let diaColor   = Color(red: 0.25, green: 0.45, blue: 0.85)
    private let pulseColor = Color(red: 0.15, green: 0.65, blue: 0.35)

    init(record: BloodPressure) {
        self.record = record
        _systolic    = State(initialValue: max(60, min(250, record.systolic)))
        _diastolic   = State(initialValue: max(40, min(150, record.diastolic)))
        _pulse       = State(initialValue: max(30, min(250, record.pulse)))
        _selectedDate = State(initialValue: record.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    bpCard
                    dateCard
                }
                .padding(16)
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.fontWeight(.medium) }
            }
        }
    }

    private var bpCard: some View {
        HStack(spacing: 8) {
            pickerColumn(label: "СИСТ.", color: sysColor, selection: $systolic, range: 60...250)
            pickerColumn(label: "ДИАСТ.", color: diaColor, selection: $diastolic, range: 40...150)
            pickerColumn(label: "ПУЛЬС", color: pulseColor, selection: $pulse, range: 30...250)
        }
    }

    private func pickerColumn(label: String, color: Color, selection: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.12))
            Picker("", selection: selection) {
                ForEach(range, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var dateCard: some View {
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
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture { showDatePicker.toggle() }

            if showDatePicker {
                Divider()
                DatePicker("", selection: $selectedDate, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .padding(.horizontal, 8)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private func save() {
        record.systolic  = systolic
        record.diastolic = diastolic
        record.pulse     = pulse
        record.date      = selectedDate
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - PDF Chart Views (for export)

private struct PDFBloodPressureChartView: View {
    let records: [BloodPressure]

    var body: some View {
        let sorted = records.sorted { $0.date < $1.date }
        let systolicValues  = sorted.map { Double($0.systolic) }
        let diastolicValues = sorted.map { Double($0.diastolic) }
        let minDia = diastolicValues.min() ?? 0
        let maxSys = systolicValues.max() ?? 0
        let minY = max(0, minDia - 10)
        let maxY = maxSys + 10

        return Chart {
            ForEach(sorted) { record in
                LineMark(x: .value("Дата", record.date), y: .value("Давление", record.systolic))
                    .foregroundStyle(.red)
                LineMark(x: .value("Дата", record.date), y: .value("Давление", record.diastolic))
                    .foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(DateFormatter.russianShortDate.string(from: date)).font(.caption2)
                    }
                }
            }
        }
        .frame(height: 200)
    }
}

private struct PulseChartForPDF: View {
    let records: [BloodPressure]

    var body: some View {
        let sorted = records.sorted { $0.date < $1.date }
        let pulseValues = sorted.map { Double($0.pulse) }
        let minPulse = pulseValues.min() ?? 0
        let maxPulse = pulseValues.max() ?? 0
        let minY = max(0, minPulse - 5)
        let maxY = maxPulse + 5

        return Chart {
            ForEach(sorted) { record in
                LineMark(x: .value("Дата", record.date), y: .value("Пульс", record.pulse))
                    .foregroundStyle(.green)
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(DateFormatter.russianShortDate.string(from: date)).font(.caption2)
                    }
                }
            }
        }
        .frame(height: 200)
    }
}
