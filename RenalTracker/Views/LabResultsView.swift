//
//  LabResultsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import Charts
import PDFKit
import UIKit

// Предзаписанная база анализов (мужские референсные значения как базовые)
struct LabTestDefinition: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let unit: String
    let referenceMin: Double?
    let referenceMax: Double?
}

enum LabTestCatalog {
    static let predefined: [LabTestDefinition] = [
        .init(name: "Креатинин", unit: "мкмоль/л", referenceMin: 60, referenceMax: 120),
        .init(name: "Гемоглобин", unit: "г/л", referenceMin: 110, referenceMax: 140),
        .init(name: "Калий", unit: "ммоль/л", referenceMin: 3.5, referenceMax: 5.5),
        .init(name: "АЛТ", unit: "ед/л", referenceMin: 40, referenceMax: 55),
        .init(name: "АСТ", unit: "ед/л", referenceMin: 40, referenceMax: 47),
        .init(name: "Кальций", unit: "ммоль/л", referenceMin: 2.15, referenceMax: 2.55),
        .init(name: "Мочевая кислота", unit: "мкмоль/л", referenceMin: 210, referenceMax: 420),
        .init(name: "Мочевина", unit: "ммоль/л", referenceMin: 2.5, referenceMax: 8.3),
        .init(name: "Общий белок", unit: "г/л", referenceMin: 64, referenceMax: 84),
        .init(name: "Паратгормон", unit: "пг/мл", referenceMin: 15, referenceMax: 65),
        .init(name: "Такролимус", unit: "пг/мл", referenceMin: 5, referenceMax: 15),
        .init(name: "Фосфор", unit: "ммоль/л", referenceMin: 0.81, referenceMax: 1.45),
        .init(name: "С-реактивный белок", unit: "мг/л", referenceMin: 0, referenceMax: 5),
        .init(name: "Фосфор", unit: "ммоль/л", referenceMin: 0.81, referenceMax: 1.45),
        .init(name: "Холестерин", unit: "ммоль/л", referenceMin: 0, referenceMax: 5.2),
        .init(name: "Ферритин", unit: "нг/мл", referenceMin: 30, referenceMax: 400),
        // TODO: расширить список на основе файла Анализы.docx
    ]
}

struct LabResultsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query(sort: \TrackedLabTest.createdAt, order: .forward)
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

    private enum LabExportPeriod {
        case days7, days30, all
    }

    // MARK: - Экспорт: реализация

    @MainActor
    private func exportAllLabsPDF() async {
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let testsWithResults = trackedTests.filter { !$0.results.isEmpty }
        guard !testsWithResults.isEmpty else { return }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 32
            var y: CGFloat = margin

            let title = "Результаты анализов"
            let subtitle = "Пациент: \(patientDisplayName)\nСформировано: \(DateFormatter.russianDateTime.string(from: Date()))"

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold)
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
            y += 28
            (subtitle as NSString).draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 50), withAttributes: subtitleAttributes)
            y += 56

            let headerFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont]
            let rowFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let rowAttributes: [NSAttributedString.Key: Any] = [.font: rowFont]

            let contentWidth = pageRect.width - 2 * margin
            let dateWidth = contentWidth * 0.4
            let valueWidth = contentWidth * 0.6
            let rowHeight: CGFloat = 16

            let dateFormatter = DateFormatter.russianDate

            for test in testsWithResults {
                let results = test.results.sorted { $0.date > $1.date }
                guard !results.isEmpty else { continue }

                // Перенос на новую страницу при нехватке места
                if y > pageRect.height - margin - 120 {
                    context.beginPage()
                    y = margin
                }

                // Название анализа
                (test.name as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttributes)
                y += rowHeight + 4

                // Заголовок таблицы (Дата | Значение)
                let dateHeaderRect = CGRect(x: margin, y: y, width: dateWidth, height: rowHeight)
                let valueHeaderRect = CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight)

                ("Дата" as NSString).draw(in: dateHeaderRect, withAttributes: headerAttributes)
                ("Значение" as NSString).draw(in: valueHeaderRect, withAttributes: headerAttributes)

                y += rowHeight + 2

                for (_, result) in results.enumerated() {
                    if y > pageRect.height - margin - 80 {
                        context.beginPage()
                        y = margin
                    }

                    _ = CGRect(x: margin, y: y, width: contentWidth, height: rowHeight)

                    let dateString = dateFormatter.string(from: result.date)
                    let valueWithUnit = result.unit.isEmpty
                        ? String(format: "%.2f", result.value)
                        : String(format: "%.2f %@", result.value, result.unit)

                    let dateRect = CGRect(x: margin + 2, y: y, width: dateWidth - 4, height: rowHeight)
                    let valueRect = CGRect(x: margin + dateWidth + 2, y: y, width: valueWidth - 4, height: rowHeight)

                    (dateString as NSString).draw(in: dateRect, withAttributes: rowAttributes)
                    (valueWithUnit as NSString).draw(in: valueRect, withAttributes: rowAttributes)

                    y += rowHeight
                }

                y += rowHeight // отступ между анализами
            }

            // Футер
            let footerText = "Сформировано приложением RenalTracker"
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let footerY = max(y + 24, pageRect.height - margin - 20)
            (footerText as NSString).draw(at: CGPoint(x: margin, y: footerY), withAttributes: footerAttributes)
        }

        _ = PDFDocument(data: data)

        let fileFormatter = DateFormatter()
        fileFormatter.locale = Locale(identifier: "ru_RU")
        fileFormatter.dateFormat = "yyyy-MM-dd"
        let datePart = fileFormatter.string(from: Date())
        let fileName = "LabResults-\(datePart).pdf"

        guard let fileURL = saveToTemp(data: data, fileName: fileName) else { return }
        presentActivityController(for: fileURL)
    }

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

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 32
            var y: CGFloat = margin

            // Заголовок
            let title = "Динамика по анализу: \(test.name)"
            let subtitle = "Пациент: \(patientDisplayName)\nЕдиница измерения: \(test.unit)\nСформировано: \(DateFormatter.russianDateTime.string(from: Date()))"

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

            // График (если есть минимум 2 точки)
            if results.count >= 2 {
                let chartView = PDFLabChartView(test: test, results: results)
                    .padding(16)
                    .clipped()
                let chartRenderer = ImageRenderer(content: chartView)
                chartRenderer.proposedSize = ProposedViewSize(width: 480, height: 180)
                if let chartImage = chartRenderer.uiImage {
                    let chartHeight: CGFloat = 160
                    let chartRect = CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: chartHeight)
                    chartImage.draw(in: chartRect)
                    y += chartHeight + 16
                }
            }

            // Таблица значений
            let contentWidth = pageRect.width - 2 * margin
            let dateWidth = contentWidth * 0.4
            let valueWidth = contentWidth * 0.6
            let rowHeight: CGFloat = 16

            let headerFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont]
            let rowFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let rowAttributes: [NSAttributedString.Key: Any] = [.font: rowFont]

            let dateHeaderRect = CGRect(x: margin, y: y, width: dateWidth, height: rowHeight)
            let valueHeaderRect = CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight)

            ("Дата" as NSString).draw(in: dateHeaderRect, withAttributes: headerAttributes)
            ("Значение" as NSString).draw(in: valueHeaderRect, withAttributes: headerAttributes)

            y += rowHeight + 2

            let dateFormatter = DateFormatter.russianDate

            for result in results.sorted(by: { $0.date > $1.date }) {
                if y > pageRect.height - margin - 80 {
                    context.beginPage()
                    y = margin
                }

                let dateString = dateFormatter.string(from: result.date)
                let valueWithUnit = test.unit.isEmpty
                    ? String(format: "%.2f", result.value)
                    : String(format: "%.2f %@", result.value, test.unit)

                let dateRect = CGRect(x: margin, y: y, width: dateWidth, height: rowHeight)
                let valueRect = CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight)

                (dateString as NSString).draw(in: dateRect, withAttributes: rowAttributes)
                (valueWithUnit as NSString).draw(in: valueRect, withAttributes: rowAttributes)

                y += rowHeight
            }

            // Статистика
            let values = results.map { $0.value }
            if let minVal = values.min(), let maxVal = values.max() {
                let avg = values.reduce(0, +) / Double(values.count)

                y += 18
                ("Итоги за период:" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
                y += 20

                let statLines = [
                    String(format: "Минимум: %.2f %@", minVal, test.unit),
                    String(format: "Максимум: %.2f %@", maxVal, test.unit),
                    String(format: "Среднее: %.2f %@", avg, test.unit)
                ]

                for line in statLines {
                    (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttributes)
                    y += 16
                }
            }
        }

        _ = PDFDocument(data: data)

        let fileFormatter = DateFormatter()
        fileFormatter.locale = Locale(identifier: "ru_RU")
        fileFormatter.dateFormat = "yyyy-MM-dd"
        let datePart = fileFormatter.string(from: Date())

        let safeName = test.name
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")

        let fileName = "LabResult-\(safeName)-\(datePart).pdf"

        guard let fileURL = saveToTemp(data: data, fileName: fileName) else { return }
        presentActivityController(for: fileURL)
    }

    // MARK: - Вспомогательные функции для файлов / шаринга

    private func saveToTemp(data: Data, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
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
            let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
            let window = scene.windows.first(where: { $0.isKeyWindow }),
            let root = window.rootViewController
        else { return }

        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(av, animated: true)
    }

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
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(test.name)
                                                    .font(.headline)
                                                if let last = test.results.sorted(by: { $0.date > $1.date }).first {
                                                    Text("\(String(format: "%.2f", last.value)) \(test.unit)")
                                                        .font(.subheadline)
                                                    Text(DateFormatter.russianDateTime.string(from: last.date))
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                } else {
                                                    Text("Нет данных")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            testToDelete = test
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                }
                            } header: {
                                HStack {
                                    Text("Отслеживаемые анализы")
                                    Spacer()
                                    Button {
                                        isShowingAddTrackedTest = true
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .imageScale(.large)
                                    }
                                    .accessibilityLabel("Добавить отслеживаемый анализ")
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Анализы")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if !trackedTests.isEmpty {
                            Button {
                                isShowingExportDialog = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .accessibilityLabel("Экспорт анализов")
                        }
                    }
                }
            }

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
        .alert("Вы уверены, что хотите удалить запись?",
               isPresented: Binding(
                    get: { testToDelete != nil },
                    set: { newValue in
                        if !newValue { testToDelete = nil }
                    }
               )) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                if let t = testToDelete {
                    modelContext.delete(t)
                    try? modelContext.save()
                }
                testToDelete = nil
            }
        }
        .confirmationDialog(
            "Экспорт анализов",
            isPresented: $isShowingExportDialog,
            titleVisibility: .visible
        ) {
            Button("Экспорт всех анализов") {
                Task {
                    await exportAllLabsPDF()
                }
            }
            if !trackedTests.isEmpty {
                Button("Экспорт по анализу...") {
                    isShowingExportTestDialog = true
                }
            }
            Button("Отмена", role: .cancel) { }
        }
        .confirmationDialog(
            "Выберите анализ",
            isPresented: $isShowingExportTestDialog,
            titleVisibility: .visible
        ) {
            ForEach(sortedTests) { test in
                Button(test.name) {
                    testForExport = test
                    isShowingExportPeriodDialog = true
                }
            }
            Button("Отмена", role: .cancel) { }
        }
        .confirmationDialog(
            "Период",
            isPresented: $isShowingExportPeriodDialog,
            titleVisibility: .visible
        ) {
            Button("7 дней") {
                guard let test = testForExport else { return }
                Task {
                    await exportSingleLabPDF(test: test, period: .days7)
                }
            }
            Button("30 дней") {
                guard let test = testForExport else { return }
                Task {
                    await exportSingleLabPDF(test: test, period: .days30)
                }
            }
            Button("Все данные") {
                guard let test = testForExport else { return }
                Task {
                    await exportSingleLabPDF(test: test, period: .all)
                }
            }
            Button("Отмена", role: .cancel) { }
        }
    }
}

// MARK: - Добавление отслеживаемого анализа

private struct AddTrackedLabTestSheet: View {
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
                    Button("Сохранить") {
                        attemptSave()
                    }
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
        if useCustomName {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            return selectedDefinition != nil
        }
    }

    private func pendingName() -> String {
        if useCustomName {
            return customName.trimmingCharacters(in: .whitespaces)
        } else {
            return selectedDefinition?.name ?? ""
        }
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
                name: def.name,
                unit: def.unit,
                referenceMin: def.referenceMin,
                referenceMax: def.referenceMax,
                isCustom: false
            )
            modelContext.insert(test)
        } else {
            let min = Double(customReferenceMin.replacingOccurrences(of: ",", with: "."))
            let max = Double(customReferenceMax.replacingOccurrences(of: ",", with: "."))
            let test = TrackedLabTest(
                name: customName.trimmingCharacters(in: .whitespaces),
                unit: customUnit.trimmingCharacters(in: .whitespaces),
                referenceMin: min,
                referenceMax: max,
                isCustom: true
            )
            modelContext.insert(test)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Детали анализа и динамика

private struct LabTestDetailView: View, Identifiable {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let id = UUID() // для sheet(item:)
    let test: TrackedLabTest

    @State private var isShowingAddResult = false
    @State private var isShowingEditReferences = false
    @State private var resultToEdit: LabResult?
    @State private var isShowingShareSheet = false
    @State private var pdfURL: URL?
    @State private var resultToDelete: LabResult?

    private var sortedResults: [LabResult] {
        test.results.sorted { $0.date < $1.date }
    }

    private var chartYDomain: ClosedRange<Double>? {
        guard !sortedResults.isEmpty else { return nil }
        let values = sortedResults.map { $0.value }
        guard let minVal = values.min(), let maxVal = values.max() else { return nil }
        let padding = (maxVal - minVal) * 0.1
        let minY = max(0, minVal - padding)
        let maxY = maxVal + padding
        return minY...maxY
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if sortedResults.isEmpty {
                    ContentUnavailableView(
                        "Нет данных по анализу",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Добавьте первое значение для анализа \"\(test.name)\".")
                    )
                } else {
                    let ruFormatter: DateFormatter = {
                        let f = DateFormatter()
                        f.locale = Locale(identifier: "ru_RU")
                        f.dateFormat = "d MMM"
                        return f
                    }()

                    if let domain = chartYDomain {
                        Chart {
                            ForEach(sortedResults) { result in
                                LineMark(
                                    x: .value("Дата", result.date),
                                    y: .value("Значение", result.value)
                                )
                                PointMark(
                                    x: .value("Дата", result.date),
                                    y: .value("Значение", result.value)
                                )
                            }
                        }
                        .chartYScale(domain: domain)
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                if let date = value.as(Date.self) {
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        Text(ruFormatter.string(from: date))
                                    }
                                }
                            }
                        }
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        .frame(height: 220)
                        .padding(.horizontal)
                    } else {
                        Chart {
                            ForEach(sortedResults) { result in
                                LineMark(
                                    x: .value("Дата", result.date),
                                    y: .value("Значение", result.value)
                                )
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic) { value in
                                if let date = value.as(Date.self) {
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel {
                                        Text(ruFormatter.string(from: date))
                                    }
                                }
                            }
                        }
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        .frame(height: 220)
                        .padding(.horizontal)
                    }

                    List {
                        ForEach(sortedResults.reversed()) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(String(format: "%.2f", result.value)) \(test.unit)")
                                    .font(.body)
                                Text(DateFormatter.russianDateTime.string(from: result.date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    resultToDelete = result
                                } label: {
                                    Label("Удалить", systemImage: "trash")
                                }

                                Button {
                                    resultToEdit = result
                                } label: {
                                    Label("Изменить", systemImage: "pencil")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(test.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingAddResult = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить значение анализа")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingEditReferences = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Редактировать референсные значения")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !sortedResults.isEmpty {
                        Button {
                            exportPDF()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Экспорт в PDF")
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddResult) {
            AddLabResultSheet(test: test)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $resultToEdit) { result in
            EditLabResultSheet(result: result)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingEditReferences) {
            EditReferenceRangeSheet(test: test)
                .presentationDetents([.medium])
        }
        .sheet(item: $pdfURL) { url in
            ShareSheet(activityItems: [url])
        }
        .alert("Вы уверены, что хотите удалить запись?",
               isPresented: Binding(
                    get: { resultToDelete != nil },
                    set: { newValue in
                        if !newValue { resultToDelete = nil }
                    }
               )) {
            Button("Отмена", role: .cancel) { }
            Button("Удалить", role: .destructive) {
                if let r = resultToDelete {
                    modelContext.delete(r)
                    try? modelContext.save()
                }
                resultToDelete = nil
            }
        }
    }

    // MARK: - PDF Export

    @MainActor
    private func exportPDF() {
        let results = sortedResults
        guard !results.isEmpty else { return }

        guard let data = generatePDFData(test: test, results: results) else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("LabReport-\(UUID().uuidString).pdf")
        do {
            try data.write(to: tempURL)
            pdfURL = tempURL
        } catch {
            print("Failed to write PDF: \(error)")
        }
    }

    @MainActor
    private func generatePDFData(test: TrackedLabTest, results: [LabResult]) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @72 dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 32
            var y: CGFloat = margin

            // Заголовки
            let title = "Отчёт по анализу: \(test.name)"
            let subtitle = "Единица измерения: \(test.unit)\nСформировано: \(DateFormatter.russianDateTime.string(from: Date()))"

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold)
            ]
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12)
            ]

            (title as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
            y += 28
            (subtitle as NSString).draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 50), withAttributes: subtitleAttributes)
            y += 56

            // График значений
            let chartView = PDFLabChartView(test: test, results: results)
            let chartRenderer = ImageRenderer(content: chartView)
            chartRenderer.proposedSize = .init(width: 500, height: 200)
            if let chartImage = chartRenderer.uiImage {
                let chartHeight: CGFloat = 160
                let chartRect = CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: chartHeight)
                chartImage.draw(in: chartRect)
                y += chartHeight + 16
            }

            // Таблица значений
            let contentWidth = pageRect.width - 2 * margin
            let dateWidth = contentWidth * 0.4
            let valueWidth = contentWidth * 0.6
            let rowHeight: CGFloat = 16

            let headerFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let headerAttributes: [NSAttributedString.Key: Any] = [.font: headerFont]
            let rowFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let rowAttributes: [NSAttributedString.Key: Any] = [.font: rowFont]

            let dateHeaderRect = CGRect(x: margin, y: y, width: dateWidth, height: rowHeight)
            let valueHeaderRect = CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight)

            ("Дата" as NSString).draw(in: dateHeaderRect, withAttributes: headerAttributes)
            ("Значение" as NSString).draw(in: valueHeaderRect, withAttributes: headerAttributes)

            y += rowHeight + 2

            let dateFormatter = DateFormatter.russianDate

            for result in results.sorted(by: { $0.date > $1.date }) {
                if y > pageRect.height - margin - 80 {
                    context.beginPage()
                    y = margin
                }

                let dateString = dateFormatter.string(from: result.date)
                let valueWithUnit = test.unit.isEmpty
                    ? String(format: "%.2f", result.value)
                    : String(format: "%.2f %@", result.value, test.unit)

                let dateRect = CGRect(x: margin, y: y, width: dateWidth, height: rowHeight)
                let valueRect = CGRect(x: margin + dateWidth, y: y, width: valueWidth, height: rowHeight)

                (dateString as NSString).draw(in: dateRect, withAttributes: rowAttributes)
                (valueWithUnit as NSString).draw(in: valueRect, withAttributes: rowAttributes)

                y += rowHeight
            }

            // Статистика
            let values = results.map { $0.value }
            if let minVal = values.min(), let maxVal = values.max() {
                let avg = values.reduce(0, +) / Double(values.count)

                y += 18
                ("Итоги за период:" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttributes)
                y += 20

                let statLines = [
                    String(format: "Минимум: %.2f %@", minVal, test.unit),
                    String(format: "Максимум: %.2f %@", maxVal, test.unit),
                    String(format: "Среднее: %.2f %@", avg, test.unit)
                ]

                for line in statLines {
                    (line as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttributes)
                    y += 16
                }
            }
        }

        _ = PDFDocument(data: data)
        return data
    }
}

// MARK: - Добавление значения анализа

private struct AddLabResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let test: TrackedLabTest

    @State private var valueText: String = ""
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section(test.name) {
                    TextField("Значение (\(test.unit))", text: $valueText)
                        .keyboardType(.decimalPad)
                }

                Section("Дата") {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
            .navigationTitle("Новое значение")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                    }
                    .disabled(Double(valueText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }

    private func save() {
        let normalized = valueText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return }

        let result = LabResult(
            name: test.name,
            value: value,
            unit: test.unit,
            date: date,
            trackedTest: test
        )
        modelContext.insert(result)
        test.results.append(result)

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Редактирование значения анализа

private struct EditLabResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let result: LabResult

    @State private var valueText: String
    @State private var date: Date

    init(result: LabResult) {
        self.result = result
        _valueText = State(initialValue: String(result.value))
        _date = State(initialValue: result.date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(result.name) {
                    TextField("Значение (\(result.unit))", text: $valueText)
                        .keyboardType(.decimalPad)
                }

                Section("Дата и время") {
                    DatePicker("Дата и время", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
            .navigationTitle("Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить изменения") {
                        save()
                    }
                    .disabled(Double(valueText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }

    private func save() {
        let normalized = valueText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return }

        result.value = value
        result.date = date

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Редактирование референсных значений

private struct EditReferenceRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let test: TrackedLabTest

    @State private var minText: String
    @State private var maxText: String
    @State private var unitText: String

    init(test: TrackedLabTest) {
        self.test = test
        if let min = test.referenceMin {
            _minText = State(initialValue: String(min))
        } else {
            _minText = State(initialValue: "")
        }
        if let max = test.referenceMax {
            _maxText = State(initialValue: String(max))
        } else {
            _maxText = State(initialValue: "")
        }
        _unitText = State(initialValue: test.unit)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Референсные значения") {
                    TextField("Нижняя граница", text: $minText)
                        .keyboardType(.decimalPad)
                    TextField("Верхняя граница", text: $maxText)
                        .keyboardType(.decimalPad)
                }

                Section("Единицы измерения") {
                    TextField("Единица измерения", text: $unitText)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Нормы для \"\(test.name)\"")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        let normalizedMin = minText.replacingOccurrences(of: ",", with: ".")
        let normalizedMax = maxText.replacingOccurrences(of: ",", with: ".")

        test.referenceMin = Double(normalizedMin)
        test.referenceMax = Double(normalizedMax)
        test.unit = unitText.trimmingCharacters(in: .whitespaces)

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - PDF Chart View

private struct PDFLabChartView: View {
    let test: TrackedLabTest
    let results: [LabResult]

    var body: some View {
        let sorted = results.sorted { $0.date < $1.date }
        let values = sorted.map { $0.value }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 0
        let padding = (maxVal - minVal) * 0.1
        let minY = max(0, minVal - padding)
        let maxY = maxVal + padding

        return Chart {
            ForEach(sorted) { result in
                LineMark(
                    x: .value("Дата", result.date),
                    y: .value("Значение", result.value)
                )
                .foregroundStyle(.blue)
                PointMark(
                    x: .value("Дата", result.date),
                    y: .value("Значение", result.value)
                )
                .foregroundStyle(.blue)
            }
        }
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
        .padding()
    }
}

// MARK: - URL Identifiable для sheet(item:)

extension URL: Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    LabResultsView()
        .modelContainer(for: [
            TrackedLabTest.self,
            LabResult.self
        ], inMemory: true)
}

