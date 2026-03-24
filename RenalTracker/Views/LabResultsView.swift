//
//  LabResultsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import Charts
import PDFKit
import UIKit

// MARK: - Lab Results View

struct LabResultsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query(sort: \TrackedLabTest.name, order: .forward)
    private var trackedTests: [TrackedLabTest]

    @State private var isShowingAddTrackedTest = false
    @State private var selectedTestForDetails: TrackedLabTest?
    @State private var pendingNavigationToTest: TrackedLabTest?
    @State private var testToDelete: TrackedLabTest?

    private var sortedTests: [TrackedLabTest] {
        trackedTests.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    @State private var isShowingExportDialog = false
    @State private var isShowingExportTestDialog = false
    @State private var isShowingExportPeriodDialog = false
    @State private var testForExport: TrackedLabTest?

    @State private var isGeneratingPDF = false
    private var calendar: Calendar { Calendar.current }

    private var patientDisplayName: String {
        guard let profile = profiles.first else { return "не указан" }
        let name = profile.name.trimmingCharacters(in: .whitespaces)
        let last = profile.lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !name.isEmpty && !last.isEmpty { return "\(name) \(last)" }
        if !name.isEmpty { return name }
        if !last.isEmpty { return last }
        return "не указан"
    }

    private enum LabExportPeriod { case days7, days30, all }

    // MARK: - Body

    var body: some View {
        ZStack {
            NavigationStack {
                Group {
                    if trackedTests.isEmpty {
                        VStack(spacing: 24) {
                            VStack(spacing: 8) {
                                Text("Анализы")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                Text("Добавьте первый отслеживаемый анализ, чтобы видеть результаты и динамику по нему.")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                            }
                            Button("Добавить отслеживаемый анализ") {
                                isShowingAddTrackedTest = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
                        List {
                            Section {
                                ForEach(sortedTests) { test in
                                    Button {
                                        selectedTestForDetails = test
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(test.name)
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                                if let latest = test.results.sorted(by: { $0.date > $1.date }).first {
                                                    Text("\(formattedValue(latest, unit: test.unit)) · \(DateFormatter.russianDate.string(from: latest.date))")
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            testToDelete = test
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                Text("ОТСЛЕЖИВАЕМЫЕ АНАЛИЗЫ")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .navigationTitle("Анализы")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 8) {
                            Button { isShowingExportDialog = true } label: {
                                ZStack {
                                    Circle().fill(Color(.secondarySystemBackground)).frame(width: 32, height: 32)
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Button { isShowingAddTrackedTest = true } label: {
                                ZStack {
                                    Circle().fill(Color.blue.opacity(0.15)).frame(width: 32, height: 32)
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }

            if isGeneratingPDF {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().scaleEffect(1.5)
                        Text("Формируем PDF...").foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(Color(.systemGray2).opacity(0.9))
                    .cornerRadius(16)
                }
            }
        }
        .sheet(isPresented: $isShowingAddTrackedTest, onDismiss: {
            if let test = pendingNavigationToTest {
                pendingNavigationToTest = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    selectedTestForDetails = test
                }
            }
        }) {
            AddTrackedLabTestSheet { existing in
                pendingNavigationToTest = existing
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedTestForDetails) { test in
            LabTestDetailView(test: test)
                .presentationDetents([.large])
        }
        .alert("Удалить анализ?",
               isPresented: Binding(
                    get: { testToDelete != nil },
                    set: { if !$0 { testToDelete = nil } }
               )) {
            Button("Удалить", role: .destructive) {
                if let t = testToDelete {
                    modelContext.delete(t)
                    try? modelContext.save()
                }
                testToDelete = nil
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Будут удалены все результаты по анализу «\(testToDelete?.name ?? "")». Это действие нельзя отменить.")
        }
        .confirmationDialog("Экспорт анализов", isPresented: $isShowingExportDialog, titleVisibility: .visible) {
            Button("Экспорт всех анализов") { Task { await exportAllLabsPDF() } }
            if !trackedTests.isEmpty {
                Button("Экспорт по анализу...") { isShowingExportTestDialog = true }
            }
            Button("Отмена", role: .cancel) { }
        }
        .confirmationDialog("Выберите анализ", isPresented: $isShowingExportTestDialog, titleVisibility: .visible) {
            ForEach(sortedTests) { test in
                Button(test.name) {
                    testForExport = test
                    isShowingExportPeriodDialog = true
                }
            }
            Button("Отмена", role: .cancel) { }
        }
        .confirmationDialog("Период", isPresented: $isShowingExportPeriodDialog, titleVisibility: .visible) {
            Button("7 дней") {
                guard let test = testForExport else { return }
                Task { await exportSingleLabPDF(test: test, period: .days7) }
            }
            Button("30 дней") {
                guard let test = testForExport else { return }
                Task { await exportSingleLabPDF(test: test, period: .days30) }
            }
            Button("Все данные") {
                guard let test = testForExport else { return }
                Task { await exportSingleLabPDF(test: test, period: .all) }
            }
            Button("Отмена", role: .cancel) { }
        }
    }

    // MARK: - Helpers

    private func formattedValue(_ result: LabResult, unit: String) -> String {
        let value = result.value
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) \(unit)".trimmingCharacters(in: .whitespaces)
            : "\(value) \(unit)".trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Export all labs PDF

    @MainActor
    private func exportAllLabsPDF() async {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let testsWithResults = trackedTests.filter { !$0.results.isEmpty }
        guard !testsWithResults.isEmpty else { return }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            let margin: CGFloat = 32
            var y: CGFloat = margin

            let titleAttributes:    [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20, weight: .bold)]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
            let headerAttributes:   [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 14, weight: .semibold)]

            let title    = "Лабораторные анализы"
            let subtitle = "Пациент: \(patientDisplayName)\nСформировано: \(DateFormatter.russianDateTime.string(from: Date()))"

            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
            y += 28
            (subtitle as NSString).draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 60), withAttributes: subtitleAttributes)
            y += 60

            let contentWidth = pageRect.width - 2 * margin
            let dateWidth    = contentWidth * 0.4
            let valueWidth   = contentWidth * 0.6
            let rowHeight: CGFloat = 16

            let rowAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
            let dateFormatter = DateFormatter.russianDate

            for test in testsWithResults {
                let results = test.results.sorted { $0.date > $1.date }
                guard !results.isEmpty else { continue }

                if y > pageRect.height - margin - 120 {
                    context.beginPage()
                    y = margin
                }

                (test.name as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttributes)
                y += rowHeight + 4

                for result in results {
                    if y > pageRect.height - margin - 20 {
                        context.beginPage()
                        y = margin
                    }
                    let valueWithUnit = test.unit.isEmpty
                        ? String(format: "%.2f", result.value)
                        : String(format: "%.2f %@", result.value, test.unit)
                    (dateFormatter.string(from: result.date) as NSString).draw(in: CGRect(x: margin, y: y, width: dateWidth, height: rowHeight), withAttributes: rowAttributes)
                    (valueWithUnit as NSString).draw(in: CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight), withAttributes: rowAttributes)
                    y += rowHeight
                }
                y += 12
            }
        }

        _ = PDFDocument(data: data)

        let datePart = DateFormatter.fileDate.string(from: Date())
        guard let fileURL = saveToTemp(data: data, fileName: "LabResults-\(datePart).pdf") else { return }
        presentActivityController(for: fileURL)
    }

    // MARK: - Export single lab PDF

    @MainActor
    private func exportSingleLabPDF(test: TrackedLabTest, period: LabExportPeriod) async {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let allResults = test.results
        guard !allResults.isEmpty else { return }

        let now = Date()
        let filtered: [LabResult]
        switch period {
        case .days7:
            let from = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filtered = allResults.filter { $0.date >= from }
        case .days30:
            let from = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filtered = allResults.filter { $0.date >= from }
        case .all:
            filtered = allResults
        }

        let results = filtered.sorted { $0.date < $1.date }
        guard !results.isEmpty else { return }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()
            let margin: CGFloat = 32
            var y: CGFloat = margin

            let titleAttributes:    [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20, weight: .bold)]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]

            let title    = "Динамика по анализу: \(test.name)"
            let subtitle = "Пациент: \(patientDisplayName)\nЕдиница измерения: \(test.unit)\nСформировано: \(DateFormatter.russianDateTime.string(from: Date()))"

            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
            y += 28
            (subtitle as NSString).draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 60), withAttributes: subtitleAttributes)
            y += 60

            if results.count >= 2 {
                let chartView = PDFLabChartView(test: test, results: results).padding(16).clipped()
                let chartRenderer = ImageRenderer(content: chartView)
                chartRenderer.proposedSize = ProposedViewSize(width: 480, height: 180)
                if let chartImage = chartRenderer.uiImage {
                    let chartHeight: CGFloat = 160
                    chartImage.draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: chartHeight))
                    y += chartHeight + 16
                }
            }

            let contentWidth = pageRect.width - 2 * margin
            let dateWidth    = contentWidth * 0.4
            let valueWidth   = contentWidth * 0.6
            let rowHeight: CGFloat = 16

            let headerAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)]
            let rowAttributes:    [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)]

            ("Дата"     as NSString).draw(in: CGRect(x: margin, y: y, width: dateWidth, height: rowHeight), withAttributes: headerAttributes)
            ("Значение" as NSString).draw(in: CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight), withAttributes: headerAttributes)
            y += rowHeight + 2

            let dateFormatter = DateFormatter.russianDate

            for result in results.sorted(by: { $0.date > $1.date }) {
                if y > pageRect.height - margin - 80 {
                    context.beginPage()
                    y = margin
                }
                let valueWithUnit = test.unit.isEmpty
                    ? String(format: "%.2f", result.value)
                    : String(format: "%.2f %@", result.value, test.unit)
                (dateFormatter.string(from: result.date) as NSString).draw(in: CGRect(x: margin, y: y, width: dateWidth, height: rowHeight), withAttributes: rowAttributes)
                (valueWithUnit as NSString).draw(in: CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight), withAttributes: rowAttributes)
                y += rowHeight
            }

            let values = results.map { $0.value }
            if let minVal = values.min(), let maxVal = values.max() {
                let avg = values.reduce(0, +) / Double(values.count)
                y += 18
                ("Итоги за период:" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
                y += 20
                for line in [
                    String(format: "Минимум: %.2f %@", minVal, test.unit),
                    String(format: "Максимум: %.2f %@", maxVal, test.unit),
                    String(format: "Среднее: %.2f %@", avg, test.unit)
                ] {
                    (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttributes)
                    y += 16
                }
            }
        }

        _ = PDFDocument(data: data)

        let safeName = test.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let datePart = DateFormatter.fileDate.string(from: Date())
        guard let fileURL = saveToTemp(data: data, fileName: "LabResult-\(safeName)-\(datePart).pdf") else { return }
        presentActivityController(for: fileURL)
    }

    // MARK: - File helpers

    private func saveToTemp(data: Data, fileName: String) -> URL? {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    @MainActor
    private func presentActivityController(for url: URL) {
        guard
            let scene  = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            let root   = window.rootViewController
        else { return }

        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(av, animated: true)
    }
}

// MARK: - PDF Chart View (used in export)

private struct PDFLabChartView: View {
    let test: TrackedLabTest
    let results: [LabResult]

    var body: some View {
        let sorted  = results.sorted { $0.date < $1.date }
        let values  = sorted.map { $0.value }
        let minVal  = values.min() ?? 0
        let maxVal  = values.max() ?? 0
        let padding = (maxVal - minVal) * 0.1
        let minY    = max(0, minVal - padding)
        let maxY    = maxVal + padding

        return Chart {
            ForEach(sorted) { result in
                LineMark(x: .value("Дата", result.date), y: .value("Значение", result.value)).foregroundStyle(.blue)
                PointMark(x: .value("Дата", result.date), y: .value("Значение", result.value)).foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
        .padding()
    }
}

#Preview {
    LabResultsView()
        .modelContainer(for: [TrackedLabTest.self, LabResult.self], inMemory: true)
}
