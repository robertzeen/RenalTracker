//
//  LabTestDetailView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import Charts
import UIKit

// MARK: - Lab Test Detail View

struct LabTestDetailView: View, Identifiable {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let id = UUID()
    let test: TrackedLabTest

    @Query private var profiles: [UserProfile]

    @State private var isShowingAddResult = false
    @State private var isShowingEditReferences = false
    @State private var resultToEdit: LabResult?
    @State private var isShowingShareSheet = false
    @State private var pdfURL: URL?
    @State private var resultToDelete: LabResult?
    @State private var isShowingNoDataAlert = false
    @State private var isShowingExportErrorAlert = false

    private var patientDisplayName: String {
        guard let profile = profiles.first else { return "не указан" }
        let name = profile.name.trimmingCharacters(in: .whitespaces)
        let last = profile.lastName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !name.isEmpty && !last.isEmpty { return "\(name) \(last)" }
        if !name.isEmpty { return name }
        if !last.isEmpty { return last }
        return "не указан"
    }

    private var sortedResults: [LabResult] {
        test.results.sorted { $0.date < $1.date }
    }

    private func formattedValue(_ result: LabResult) -> String {
        let value = result.value
        return value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) \(test.unit)".trimmingCharacters(in: .whitespaces)
            : "\(value) \(test.unit)".trimmingCharacters(in: .whitespaces)
    }

    private var chartYDomain: ClosedRange<Double>? {
        guard !sortedResults.isEmpty else { return nil }
        let values = sortedResults.map { $0.value }
        guard let minVal = values.min(), let maxVal = values.max() else { return nil }
        let padding = (maxVal - minVal) * 0.1
        return max(0, minVal - padding)...maxVal + padding
    }

    var body: some View {
        NavigationStack {
            Group {
                if sortedResults.isEmpty {
                    ContentUnavailableView(
                        "Нет данных по анализу",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Добавьте первое значение для анализа \"\(test.name)\".")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let domain = chartYDomain {
                                Chart {
                                    ForEach(sortedResults) { result in
                                        LineMark(x: .value("Дата", result.date), y: .value("Значение", result.value))
                                        PointMark(x: .value("Дата", result.date), y: .value("Значение", result.value))
                                    }
                                }
                                .chartYScale(domain: domain)
                                .chartXAxis(.hidden)
                                .frame(height: 220)
                                .padding(.horizontal)
                            } else {
                                Chart {
                                    ForEach(sortedResults) { result in
                                        LineMark(x: .value("Дата", result.date), y: .value("Значение", result.value))
                                    }
                                }
                                .chartXAxis(.hidden)
                                .frame(height: 220)
                                .padding(.horizontal)
                            }

                            let reversedResults = Array(sortedResults.reversed())
                            LazyVStack(spacing: 0) {
                                ForEach(Array(reversedResults.enumerated()), id: \.element.id) { index, result in
                                    Button {
                                        resultToEdit = result
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(formattedValue(result))
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(.primary)
                                                Text(DateFormatter.russianDateTime.string(from: result.date))
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.tertiary)
                                        }
                                        .padding(14)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            resultToDelete = result
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }

                                    if index < reversedResults.count - 1 {
                                        Divider().padding(.leading, 14)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
            .navigationTitle(test.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        Button {
                            isShowingEditReferences = true
                        } label: {
                            ZStack {
                                Circle().fill(Color(.secondarySystemBackground)).frame(width: 32, height: 32)
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if !sortedResults.isEmpty {
                            Button { exportPDF() } label: {
                                ZStack {
                                    Circle().fill(Color(.secondarySystemBackground)).frame(width: 32, height: 32)
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button {
                            isShowingAddResult = true
                        } label: {
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
        .alert("Удалить измерение?",
               isPresented: Binding(
                    get: { resultToDelete != nil },
                    set: { if !$0 { resultToDelete = nil } }
               )) {
            Button("Удалить", role: .destructive) {
                if let r = resultToDelete {
                    modelContext.delete(r)
                    try? modelContext.save()
                }
                resultToDelete = nil
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

    // MARK: - PDF Export

    @MainActor
    private func exportPDF() {
        let results = sortedResults
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

        let data = LabTestDetailPDFExporter.makeData(
            testName: testName,
            unit: testUnit,
            results: resultsSnapshot,
            periodDescription: nil,
            patientName: name,
            chartImage: chartImage
        )

        do {
            let url = try PDFExporter.saveToTempFile(data: data, fileNamePrefix: "Lab-\(testName)")
            pdfURL = url
        } catch {
            print("Failed to save lab PDF: \(error)")
            isShowingExportErrorAlert = true
        }
    }
}

// MARK: - Add Lab Result Sheet

private struct AddLabResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let test: TrackedLabTest

    @State private var valueText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var showDatePicker = false

    private var isValid: Bool {
        Double(valueText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text(test.name.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        Divider().padding(.leading, 14)

                        HStack {
                            TextField("Значение", text: $valueText)
                                .font(.system(size: 15, weight: .medium))
                                .keyboardType(.decimalPad)
                            Text(test.unit)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))

                    dateCard
                }
                .padding(16)
            }
            .navigationTitle("Новое значение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.medium)
                        .disabled(!isValid)
                }
            }
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
        let normalized = valueText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return }
        let result = LabResult(name: test.name, value: value, unit: test.unit, date: selectedDate, trackedTest: test)
        modelContext.insert(result)
        test.results.append(result)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Lab Result Sheet

private struct EditLabResultSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let result: LabResult

    @State private var valueText: String
    @State private var selectedDate: Date
    @State private var showDatePicker = false

    init(result: LabResult) {
        self.result = result
        let v = result.value
        let formatted = v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : "\(v)"
        _valueText    = State(initialValue: formatted)
        _selectedDate = State(initialValue: result.date)
    }

    private var isValid: Bool {
        Double(valueText.replacingOccurrences(of: ",", with: ".")) != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text(result.name.uppercased())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        Divider().padding(.leading, 14)

                        HStack {
                            TextField("Значение", text: $valueText)
                                .font(.system(size: 15, weight: .medium))
                                .keyboardType(.decimalPad)
                            Text(result.unit)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))

                    dateCard
                }
                .padding(16)
            }
            .navigationTitle("Редактирование")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save() }
                        .fontWeight(.medium)
                        .disabled(!isValid)
                }
            }
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
        let normalized = valueText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized) else { return }
        result.value = value
        result.date  = selectedDate
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Edit Reference Range Sheet

private struct EditReferenceRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let test: TrackedLabTest

    @State private var minText: String
    @State private var maxText: String
    @State private var unitText: String

    init(test: TrackedLabTest) {
        self.test = test
        _minText  = State(initialValue: Self.formatOptional(test.referenceMin))
        _maxText  = State(initialValue: Self.formatOptional(test.referenceMax))
        _unitText = State(initialValue: test.unit)
    }

    private static func formatOptional(_ value: Double?) -> String {
        guard let v = value else { return "" }
        return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("НИЖНЯЯ ГРАНИЦА")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                TextField("Введите значение", text: $minText)
                                    .font(.system(size: 15, weight: .medium))
                                    .keyboardType(.decimalPad)
                            }
                            Spacer()
                        }
                        .padding(14)

                        Divider().padding(.leading, 14)

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("ВЕРХНЯЯ ГРАНИЦА")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                                TextField("Введите значение", text: $maxText)
                                    .font(.system(size: 15, weight: .medium))
                                    .keyboardType(.decimalPad)
                            }
                            Spacer()
                        }
                        .padding(14)
                    }
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ЕДИНИЦЫ ИЗМЕРЕНИЯ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("пг/мл, ммоль/л...", text: $unitText)
                                .font(.system(size: 15, weight: .medium))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
                }
                .padding(16)
            }
            .navigationTitle("Референсные значения")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { save(); dismiss() }.fontWeight(.medium)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private func save() {
        test.referenceMin = Double(minText.replacingOccurrences(of: ",", with: "."))
        test.referenceMax = Double(maxText.replacingOccurrences(of: ",", with: "."))
        test.unit         = unitText.trimmingCharacters(in: .whitespaces)
        try? modelContext.save()
    }
}

// MARK: - URL Identifiable для sheet(item:)

extension URL: Identifiable {
    public var id: String { absoluteString }
}
