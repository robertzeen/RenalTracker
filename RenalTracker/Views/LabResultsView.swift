//
//  LabResultsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import Charts
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
    @State private var pdfURL: URL?
    @State private var isSharePresented = false
    @State private var isShowingNoDataAlert = false
    @State private var isShowingExportErrorAlert = false
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
        .sheet(isPresented: $isSharePresented) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
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
        guard !testsWithResults.isEmpty else { isShowingNoDataAlert = true; return }

        let snapshot: [LabResultsPDFExporter.Test] = testsWithResults.map { test in
            LabResultsPDFExporter.Test(
                name: test.name,
                unit: test.unit,
                results: test.results.map { .init(date: $0.date, value: $0.value) }
            )
        }
        let name = patientDisplayName

        let data = await Task.detached(priority: .userInitiated) {
            LabResultsPDFExporter.makeData(tests: snapshot, patientName: name)
        }.value

        do {
            let url = try PDFExporter.saveToTempFile(data: data, fileNamePrefix: "LabResults")
            pdfURL = url
            isSharePresented = true
        } catch {
            print("Failed to save lab results PDF: \(error)")
            isShowingExportErrorAlert = true
        }
    }

    // MARK: - Export single lab PDF

    @MainActor
    private func exportSingleLabPDF(test: TrackedLabTest, period: LabExportPeriod) async {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let allResults = test.results
        guard !allResults.isEmpty else { isShowingNoDataAlert = true; return }

        let now = Date()
        let filtered: [LabResult]
        let periodText: String
        switch period {
        case .days7:
            let from = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filtered = allResults.filter { $0.date >= from }
            periodText = "за последние 7 дней"
        case .days30:
            let from = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            filtered = allResults.filter { $0.date >= from }
            periodText = "за последние 30 дней"
        case .all:
            filtered = allResults
            periodText = "за весь период наблюдения"
        }

        let results = filtered.sorted { $0.date < $1.date }
        guard !results.isEmpty else { isShowingNoDataAlert = true; return }

        let resultsSnapshot: [LabTestDetailPDFExporter.Result] = results.map {
            .init(date: $0.date, value: $0.value)
        }
        let testName = test.name
        let testUnit = test.unit
        let name = patientDisplayName

        let chartImage: UIImage? = {
            guard results.count >= 2 else { return nil }
            let points = resultsSnapshot.map { PDFLabChartView.Point(date: $0.date, value: $0.value) }
            let chart = PDFLabChartView(points: points)
            let renderer = ImageRenderer(content: chart)
            renderer.proposedSize = ProposedViewSize(width: 530, height: 240)
            return renderer.uiImage
        }()

        let data = await Task.detached(priority: .userInitiated) {
            LabTestDetailPDFExporter.makeData(
                testName: testName,
                unit: testUnit,
                results: resultsSnapshot,
                periodDescription: periodText,
                patientName: name,
                chartImage: chartImage
            )
        }.value

        do {
            let url = try PDFExporter.saveToTempFile(data: data, fileNamePrefix: "Lab-\(testName)")
            pdfURL = url
            isSharePresented = true
        } catch {
            print("Failed to save single lab PDF: \(error)")
            isShowingExportErrorAlert = true
        }
    }
}

#Preview {
    LabResultsView()
        .modelContainer(for: [TrackedLabTest.self, LabResult.self], inMemory: true)
}
