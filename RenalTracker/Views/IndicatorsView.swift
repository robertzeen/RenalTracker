//
//  IndicatorsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import Charts
import PDFKit
import UIKit

// Период для графиков (общий для всех)
enum ChartPeriod: String, CaseIterable {
    case days7 = "7 дней"
    case days30 = "30 дней"
    case all = "Всё время"

    var title: String { rawValue }
}

struct IndicatorsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BloodPressure.date, order: .forward)
    private var bloodPressureRecords: [BloodPressure]

    @Query(sort: \Weight.date, order: .forward)
    private var weightRecords: [Weight]

    @State private var chartPeriod: ChartPeriod = .days7
    @State private var isShowingAddBloodPressure = false
    @State private var isShowingAddWeight = false

    private var recentBloodPressureChart: [BloodPressure] {
        switch chartPeriod {
        case .days7:
            return bloodPressureRecords.filter { $0.date >= Date().addingTimeInterval(-7 * 24 * 3600) }
        case .days30:
            return bloodPressureRecords.filter { $0.date >= Date().addingTimeInterval(-30 * 24 * 3600) }
        case .all:
            return bloodPressureRecords
        }
    }

    private var recentWeightChart: [Weight] {
        switch chartPeriod {
        case .days7:
            return weightRecords.filter { $0.date >= Date().addingTimeInterval(-7 * 24 * 3600) }
        case .days30:
            return weightRecords.filter { $0.date >= Date().addingTimeInterval(-30 * 24 * 3600) }
        case .all:
            return weightRecords
        }
    }

    private var bloodPressureYDomain: ClosedRange<Double>? {
        guard recentBloodPressureChart.count >= 2 else { return nil }

        let values = recentBloodPressureChart.flatMap { record in
            [Double(record.systolic), Double(record.diastolic)]
        }

        guard let minVal = values.min(), let maxVal = values.max() else { return nil }

        let paddedMin = max(0, minVal - 10)
        let paddedMax = maxVal + 10

        return paddedMin...paddedMax
    }

    private var pulseYDomain: ClosedRange<Double>? {
        guard recentBloodPressureChart.count >= 2 else { return nil }

        let values = recentBloodPressureChart.map { Double($0.pulse) }

        guard let minVal = values.min(), let maxVal = values.max() else { return nil }

        let paddedMin = max(0, minVal - 5)
        let paddedMax = maxVal + 5

        return paddedMin...paddedMax
    }

    private var weightYDomain: ClosedRange<Double>? {
        guard recentWeightChart.count >= 2 else { return nil }

        let values = recentWeightChart.map { $0.valueKg }

        guard let minVal = values.min(), let maxVal = values.max() else { return nil }

        let paddedMin = max(0, minVal - 1)
        let paddedMax = maxVal + 1

        return paddedMin...paddedMax
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Период", selection: $chartPeriod) {
                        ForEach(ChartPeriod.allCases, id: \.rawValue) { period in
                            Text(period.title).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    bloodPressureCard
                    pulseCard
                    weightCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Показатели")
        }
        .sheet(isPresented: $isShowingAddBloodPressure) {
            AddBloodPressureSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingAddWeight) {
            AddWeightSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var bloodPressureCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ДАВЛЕНИЕ И ПУЛЬС")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let last = bloodPressureRecords.last {
                        Text("Последнее: \(last.systolic)/\(last.diastolic), пульс \(last.pulse)")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { isShowingAddBloodPressure = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(14)

            Divider()

            if recentBloodPressureChart.count < 2 {
                Text("Недостаточно данных для графика")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(recentBloodPressureChart) { record in
                        LineMark(
                            x: .value("Дата", record.date),
                            y: .value("Сист.", record.systolic),
                            series: .value("Тип", "systolic")
                        )
                        .foregroundStyle(Color.red)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Сист.", record.systolic)
                        )
                        .foregroundStyle(Color.red)
                        .symbolSize(40)
                    }

                    ForEach(recentBloodPressureChart) { record in
                        LineMark(
                            x: .value("Дата", record.date),
                            y: .value("Диаст.", record.diastolic),
                            series: .value("Тип", "diastolic")
                        )
                        .foregroundStyle(Color.blue)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Диаст.", record.diastolic)
                        )
                        .foregroundStyle(Color.blue)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: bloodPressureYDomain ?? 60...180)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text("\(val)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }

            Divider()

            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Сист.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Circle().fill(Color.blue).frame(width: 8, height: 8)
                    Text("Диаст.").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink {
                    BloodPressureListView()
                } label: {
                    Text("Все измерения →")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var pulseCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ПУЛЬС")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let last = bloodPressureRecords.last {
                        Text("Последнее: \(last.pulse) уд/мин")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(14)

            Divider()

            if recentBloodPressureChart.count < 2 {
                Text("Недостаточно данных для графика")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(recentBloodPressureChart) { record in
                        LineMark(
                            x: .value("Дата", record.date),
                            y: .value("Пульс", record.pulse)
                        )
                        .foregroundStyle(Color.green)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Пульс", record.pulse)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: pulseYDomain ?? 40...120)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text("\(val)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }

    private var weightCard: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ВЕС")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    if let last = weightRecords.last {
                        let wVal = last.valueKg
                        let wStr = wVal.truncatingRemainder(dividingBy: 1) == 0
                            ? "\(Int(wVal))" : String(format: "%.1f", wVal)
                        Text("Последнее: \(wStr) кг")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { isShowingAddWeight = true } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(14)

            Divider()

            if recentWeightChart.count < 2 {
                Text("Недостаточно данных для графика")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            } else {
                Chart {
                    ForEach(recentWeightChart) { record in
                        LineMark(
                            x: .value("Дата", record.date),
                            y: .value("Вес", record.valueKg)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Дата", record.date),
                            y: .value("Вес", record.valueKg)
                        )
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: weightYDomain ?? 40.0...120.0)
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                let s = val.truncatingRemainder(dividingBy: 1) == 0
                                    ? "\(Int(val))" : String(format: "%.1f", val)
                                Text(s)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 120)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
            }

            Divider()

            HStack {
                Spacer()
                NavigationLink {
                    WeightListView()
                } label: {
                    Text("Все измерения →")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
    }
}

// MARK: - Blood Pressure List (все записи)

struct BloodPressureListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BloodPressure.date, order: .reverse)
    private var records: [BloodPressure]

    @State private var recordToEdit: BloodPressure?
    @State private var recordToDelete: BloodPressure?
    @State private var showDeleteConfirmation = false
    @State private var showExportDialog = false
    @State private var pdfURL: URL?
    @State private var isSharePresented = false

    private enum ExportPeriod {
        case days7
        case days30
        case all

        var title: String {
            switch self {
            case .days7: return "За 7 дней"
            case .days30: return "За 30 дней"
            case .all: return "Все данные"
            }
        }
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
            .map { (key, value) in
                let sorted = value.sorted { $0.date > $1.date }
                return (date: key, records: sorted)
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "Нет записей",
                    systemImage: "heart.text.square",
                    description: Text("Добавьте измерение давления на экране «Показатели»")
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !records.isEmpty {
                    Button {
                        showExportDialog = true
                    } label: {
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
            Button(ExportPeriod.days7.title) {
                exportPDF(for: .days7)
            }
            Button(ExportPeriod.days30.title) {
                exportPDF(for: .days30)
            }
            Button(ExportPeriod.all.title) {
                exportPDF(for: .all)
            }
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
        let filteredRecords: [BloodPressure]
        let now = Date()

        switch period {
        case .days7:
            let from = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filteredRecords = records.filter { $0.date >= from }
        case .days30:
            let from = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filteredRecords = records.filter { $0.date >= from }
        case .all:
            filteredRecords = records
        }

        guard !filteredRecords.isEmpty else { return }

        let periodDescription: String
        switch period {
        case .days7: periodDescription = "за последние 7 дней"
        case .days30: periodDescription = "за последние 30 дней"
        case .all: periodDescription = "за весь период наблюдения"
        }

        guard let data = generatePDFData(records: filteredRecords, periodDescription: periodDescription) else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("BPReport-\(UUID().uuidString).pdf")
        do {
            try data.write(to: tempURL)
            pdfURL = tempURL
            isSharePresented = true
        } catch {
            print("Failed to write PDF: \(error)")
        }
    }

    @MainActor
    private func generatePDFData(records: [BloodPressure], periodDescription: String) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @ 72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 32
            var y: CGFloat = margin

            // Заголовки
            let title = "Отчёт по давлению и пульсу"
            let subtitle = "\(periodDescription.capitalized)\nСформировано: \(DateFormatter.russianDateTime.string(from: Date()))"

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold)
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
            y += 28
            (subtitle as NSString).draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 60), withAttributes: subtitleAttributes)
            y += 60

            // Таблица заголовков
            let contentWidth = pageRect.width - 2 * margin
            let dateWidth = contentWidth * 0.25
            let timeWidth = contentWidth * 0.15
            let systWidth = contentWidth * 0.2
            let diastWidth = contentWidth * 0.2
            let pulseWidth = contentWidth * 0.2
            let rowHeight: CGFloat = 16

            let headerFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont]
            let rowFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let rowAttributes: [NSAttributedString.Key: Any] = [.font: rowFont]

            // Заголовок таблицы
            let dateHeaderRect = CGRect(x: margin, y: y, width: dateWidth, height: rowHeight)
            let timeHeaderRect = CGRect(x: margin + dateWidth, y: y, width: timeWidth, height: rowHeight)
            let systHeaderRect = CGRect(x: margin + dateWidth + timeWidth, y: y, width: systWidth, height: rowHeight)
            let diastHeaderRect = CGRect(x: margin + dateWidth + timeWidth + systWidth, y: y, width: diastWidth, height: rowHeight)
            let pulseHeaderRect = CGRect(x: margin + dateWidth + timeWidth + systWidth + diastWidth, y: y, width: pulseWidth, height: rowHeight)

            ("Дата" as NSString).draw(in: dateHeaderRect, withAttributes: headerAttributes)
            ("Время" as NSString).draw(in: timeHeaderRect, withAttributes: headerAttributes)
            ("Сист." as NSString).draw(in: systHeaderRect, withAttributes: headerAttributes)
            ("Диаст." as NSString).draw(in: diastHeaderRect, withAttributes: headerAttributes)
            ("Пульс" as NSString).draw(in: pulseHeaderRect, withAttributes: headerAttributes)

            y += rowHeight + 2

            let dateFormatter = DateFormatter.russianDate
            let timeFormatter = DateFormatter.russianTime

            for record in records.sorted(by: { $0.date > $1.date }) {
                if y > pageRect.height - margin - 80 {
                    context.beginPage()
                    y = margin
                }
                let dateString = dateFormatter.string(from: record.date)
                let timeString = timeFormatter.string(from: record.date)
                let systString = "\(record.systolic)"
                let diastString = "\(record.diastolic)"
                let pulseString = "\(record.pulse)"

                let dateRect = CGRect(x: margin, y: y, width: dateWidth, height: rowHeight)
                let timeRect = CGRect(x: margin + dateWidth, y: y, width: timeWidth, height: rowHeight)
                let systRect = CGRect(x: margin + dateWidth + timeWidth, y: y, width: systWidth, height: rowHeight)
                let diastRect = CGRect(x: margin + dateWidth + timeWidth + systWidth, y: y, width: diastWidth, height: rowHeight)
                let pulseRect = CGRect(x: margin + dateWidth + timeWidth + systWidth + diastWidth, y: y, width: pulseWidth, height: rowHeight)

                (dateString as NSString).draw(in: dateRect, withAttributes: rowAttributes)
                (timeString as NSString).draw(in: timeRect, withAttributes: rowAttributes)
                (systString as NSString).draw(in: systRect, withAttributes: rowAttributes)
                (diastString as NSString).draw(in: diastRect, withAttributes: rowAttributes)
                (pulseString as NSString).draw(in: pulseRect, withAttributes: rowAttributes)

                y += rowHeight
            }

            // Статистика
            let systolicValues = records.map { Double($0.systolic) }
            let diastolicValues = records.map { Double($0.diastolic) }
            let pulseValues = records.map { Double($0.pulse) }

            func statsString(name: String, values: [Double]) -> String {
                guard let min = values.min(), let max = values.max() else { return "" }
                let avg = values.reduce(0, +) / Double(values.count)
                return String(format: "%@: мин %.0f, макс %.0f, ср %.1f", name, min, max, avg)
            }

            y += 16
            ("Итоги за период:" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
            y += 20

            let lines = [
                statsString(name: "Систолическое", values: systolicValues),
                statsString(name: "Диастолическое", values: diastolicValues),
                statsString(name: "Пульс", values: pulseValues)
            ]

            for line in lines where !line.isEmpty {
                (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttributes)
                y += 16
            }
        }

        // Обёртка через PDFKit (по требованию задачи)
        _ = PDFDocument(data: data)
        return data
    }
}

// MARK: - Weight List (все записи)

struct WeightListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Weight.date, order: .reverse)
    private var records: [Weight]

    @State private var recordToEdit: Weight?
    @State private var recordToDelete: Weight?
    @State private var showDeleteConfirmation = false
    @State private var showExportDialog = false
    @State private var pdfURL: URL?
    @State private var isSharePresented = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: "ru_RU")
        return cal
    }

    private var groupedByMonth: [(date: Date, records: [Weight])] {
        let grouped = Dictionary(grouping: records) { record -> Date in
            let comps = calendar.dateComponents([.year, .month], from: record.date)
            return calendar.date(from: comps) ?? record.date
        }
        return grouped
            .map { key, value in (date: key, records: value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    private func formattedWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    var body: some View {
        Group {
            if records.isEmpty {
                ContentUnavailableView(
                    "Нет записей",
                    systemImage: "scalemass",
                    description: Text("Добавьте измерение веса на экране «Показатели»")
                )
            } else {
                List {
                    ForEach(groupedByMonth, id: \.date) { group in
                        Section {
                            ForEach(group.records) { record in
                                weightRow(record)
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
        .navigationTitle("Вес")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Назад")
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if !records.isEmpty {
                    Button {
                        showExportDialog = true
                    } label: {
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
            EditWeightSheet(record: record)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Экспорт PDF", isPresented: $showExportDialog, titleVisibility: .visible) {
            Button("За 7 дней") { exportPDF(period: 7) }
            Button("За 30 дней") { exportPDF(period: 30) }
            Button("Все данные") { exportPDF(period: nil) }
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
    }

    @ViewBuilder
    private func weightRow(_ record: Weight) -> some View {
        Button {
            recordToEdit = record
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(formattedWeight(record.valueKg)) кг")
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

    @MainActor
    private func exportPDF(period: Int?) {
        let filtered: [Weight]
        if let days = period {
            let from = Date().addingTimeInterval(Double(-days) * 86400)
            filtered = records.filter { $0.date >= from }
        } else {
            filtered = records
        }
        guard !filtered.isEmpty else { return }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            let margin: CGFloat = 32
            var y: CGFloat = margin

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20, weight: .bold)]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
            let rowAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)]

            ("Отчёт по весу" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 28
            ("Сформировано: \(DateFormatter.russianDateTime.string(from: Date()))" as NSString)
                .draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 20), withAttributes: bodyAttrs)
            y += 32

            let contentWidth = pageRect.width - 2 * margin
            let dateWidth = contentWidth * 0.5
            let valWidth = contentWidth * 0.5
            let rowH: CGFloat = 16

            ("Дата и время" as NSString).draw(in: CGRect(x: margin, y: y, width: dateWidth, height: rowH), withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)])
            ("Вес (кг)" as NSString).draw(in: CGRect(x: margin + dateWidth, y: y, width: valWidth, height: rowH), withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)])
            y += rowH + 2

            for record in filtered.sorted(by: { $0.date > $1.date }) {
                if y > pageRect.height - margin - 20 {
                    context.beginPage()
                    y = margin
                }
                (DateFormatter.russianDateTime.string(from: record.date) as NSString)
                    .draw(in: CGRect(x: margin, y: y, width: dateWidth, height: rowH), withAttributes: rowAttrs)
                (formattedWeight(record.valueKg) as NSString)
                    .draw(in: CGRect(x: margin + dateWidth, y: y, width: valWidth, height: rowH), withAttributes: rowAttrs)
                y += rowH
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("WeightReport-\(UUID().uuidString).pdf")
        try? data.write(to: url)
        pdfURL = url
        isSharePresented = true
    }
}

// MARK: - Вспомогательные графики для PDF

private struct PDFBloodPressureChartView: View {
    let records: [BloodPressure]

    var body: some View {
        let sorted = records.sorted { $0.date < $1.date }
        let systolicValues = sorted.map { Double($0.systolic) }
        let diastolicValues = sorted.map { Double($0.diastolic) }
        let minDia = diastolicValues.min() ?? 0
        let maxSys = systolicValues.max() ?? 0
        let minY = max(0, minDia - 10)
        let maxY = maxSys + 10

        let shortDateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ru_RU")
            f.dateFormat = "d MMM"
            return f
        }()

        return Chart {
            ForEach(sorted) { record in
                LineMark(
                    x: .value("Дата", record.date),
                    y: .value("Давление", record.systolic)
                )
                .foregroundStyle(.red)

                LineMark(
                    x: .value("Дата", record.date),
                    y: .value("Давление", record.diastolic)
                )
                .foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(shortDateFormatter.string(from: date))
                            .font(.caption2)
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

        let shortDateFormatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ru_RU")
            f.dateFormat = "d MMM"
            return f
        }()

        return Chart {
            ForEach(sorted) { record in
                LineMark(
                    x: .value("Дата", record.date),
                    y: .value("Пульс", record.pulse)
                )
                .foregroundStyle(.green)
            }
        }
        .chartYScale(domain: minY...maxY)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(shortDateFormatter.string(from: date))
                            .font(.caption2)
                    }
                }
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Add Blood Pressure Sheet

private struct AddBloodPressureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var systolic: Int = 120
    @State private var diastolic: Int = 80
    @State private var pulse: Int = 70
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false

    private let sysColor  = Color(red: 0.85, green: 0.25, blue: 0.25)
    private let diaColor  = Color(red: 0.25, green: 0.45, blue: 0.85)
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var bpCard: some View {
        HStack(spacing: 8) {
            VStack(spacing: 0) {
                Text("СИСТ.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(sysColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(sysColor.opacity(0.12))

                Picker("", selection: $systolic) {
                    ForEach(60...250, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))

            VStack(spacing: 0) {
                Text("ДИАСТ.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(diaColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(diaColor.opacity(0.12))

                Picker("", selection: $diastolic) {
                    ForEach(40...150, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))

            VStack(spacing: 0) {
                Text("ПУЛЬС")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(pulseColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(pulseColor.opacity(0.12))

                Picker("", selection: $pulse) {
                    ForEach(30...250, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))
        }
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
                        .foregroundStyle(.primary)
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
                DatePicker("", selection: $selectedDate,
                           in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .padding(.horizontal, 8)
                    .onChange(of: selectedDate) { _, _ in
                        showDatePicker = false
                    }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.separator), lineWidth: 0.5))
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
        _systolic = State(initialValue: max(60, min(250, record.systolic)))
        _diastolic = State(initialValue: max(40, min(150, record.diastolic)))
        _pulse = State(initialValue: max(30, min(250, record.pulse)))
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var bpCard: some View {
        HStack(spacing: 8) {
            VStack(spacing: 0) {
                Text("СИСТ.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(sysColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(sysColor.opacity(0.12))

                Picker("", selection: $systolic) {
                    ForEach(60...250, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))

            VStack(spacing: 0) {
                Text("ДИАСТ.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(diaColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(diaColor.opacity(0.12))

                Picker("", selection: $diastolic) {
                    ForEach(40...150, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))

            VStack(spacing: 0) {
                Text("ПУЛЬС")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(pulseColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(pulseColor.opacity(0.12))

                Picker("", selection: $pulse) {
                    ForEach(30...250, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))
        }
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
                        .foregroundStyle(.primary)
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
                DatePicker("", selection: $selectedDate,
                           in: ...Date(),
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .padding(.horizontal, 8)
                    .onChange(of: selectedDate) { _, _ in
                        showDatePicker = false
                    }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.separator), lineWidth: 0.5))
    }

    private func save() {
        record.systolic = systolic
        record.diastolic = diastolic
        record.pulse = pulse
        record.date = selectedDate
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Shared wheel picker

private struct BPWheelPicker: View {
    @Binding var systolic: Int
    @Binding var diastolic: Int
    @Binding var pulse: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Picker("", selection: $systolic) {
                    ForEach(60...250, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 120)
                .clipped()

                Text("/")
                    .font(.title2)
                    .padding(.horizontal, 4)

                Picker("", selection: $diastolic) {
                    ForEach(40...150, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 120)
                .clipped()

                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)

                Picker("", selection: $pulse) {
                    ForEach(30...250, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 120)
                .clipped()
            }

            HStack(spacing: 0) {
                Text("Сист.")
                    .frame(width: 80)
                Spacer()
                    .frame(width: 20)
                Text("Диаст.")
                    .frame(width: 80)
                Spacer()
                    .frame(width: 40)
                Text("Пульс")
                    .frame(width: 80)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Add Weight Sheet

private struct AddWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var kilograms: Int = 80
    @State private var decimalPart: Int = 0
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text("ВЕС")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        HStack(spacing: 0) {
                            Spacer()
                            Picker("", selection: $kilograms) {
                                ForEach(20...250, id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 120)
                            .clipped()

                            Text(",")
                                .font(.title)
                                .padding(.horizontal, 4)

                            Picker("", selection: $decimalPart) {
                                ForEach(0...9, id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 120)
                            .clipped()

                            Text("кг")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .padding(.bottom, 14)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ДАТА И ВРЕМЯ")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(DateFormatter.russianDateTime.string(from: selectedDate))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
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
                            DatePicker("", selection: $selectedDate,
                                       in: ...Date(),
                                       displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .padding(.horizontal, 8)
                                .onChange(of: selectedDate) { _, _ in
                                    showDatePicker = false
                                }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))
                }
                .padding(16)
            }
            .navigationTitle("Новая запись веса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private func save() {
        let value = Double(kilograms) + Double(decimalPart) / 10.0
        let record = Weight(valueKg: value, date: selectedDate)
        modelContext.insert(record)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Weight Sheet

private struct EditWeightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let record: Weight

    @State private var kilograms: Int
    @State private var decimalPart: Int
    @State private var selectedDate: Date
    @State private var showDatePicker = false

    init(record: Weight) {
        self.record = record
        let kg = Int(record.valueKg)
        let dec = Int((record.valueKg * 10).truncatingRemainder(dividingBy: 10))
        _kilograms = State(initialValue: max(20, min(250, kg)))
        _decimalPart = State(initialValue: max(0, min(9, dec)))
        _selectedDate = State(initialValue: record.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text("ВЕС")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        HStack(spacing: 0) {
                            Spacer()
                            Picker("", selection: $kilograms) {
                                ForEach(20...250, id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 120)
                            .clipped()

                            Text(",")
                                .font(.title)
                                .padding(.horizontal, 4)

                            Picker("", selection: $decimalPart) {
                                ForEach(0...9, id: \.self) { v in
                                    Text("\(v)").tag(v)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 80, height: 120)
                            .clipped()

                            Text("кг")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .padding(.bottom, 14)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))

                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ДАТА И ВРЕМЯ")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(DateFormatter.russianDateTime.string(from: selectedDate))
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.primary)
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
                            DatePicker("", selection: $selectedDate,
                                       in: ...Date(),
                                       displayedComponents: [.date, .hourAndMinute])
                                .datePickerStyle(.graphical)
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                                .padding(.horizontal, 8)
                                .onChange(of: selectedDate) { _, _ in
                                    showDatePicker = false
                                }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(.separator), lineWidth: 0.5))
                }
                .padding(16)
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.medium)
                }
            }
        }
    }

    private func save() {
        record.valueKg = Double(kilograms) + Double(decimalPart) / 10.0
        record.date = selectedDate
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Weight Wheel Picker

private struct WeightWheelPicker: View {
    @Binding var kilograms: Int
    @Binding var decimalPart: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("", selection: $kilograms) {
                ForEach(20...250, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 100, height: 120)
            .clipped()

            Text(",")
                .font(.title)
                .padding(.horizontal, 4)

            Picker("", selection: $decimalPart) {
                ForEach([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 120)
            .clipped()

            Text("кг")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
    }
}

// MARK: - Identifiable for sheet(item:)

extension BloodPressure: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

extension Weight: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

#Preview {
    IndicatorsView()
        .modelContainer(for: [
            BloodPressure.self,
            Weight.self
        ], inMemory: true)
}
