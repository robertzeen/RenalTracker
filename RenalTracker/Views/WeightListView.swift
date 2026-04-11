//
//  WeightListView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import PDFKit
import UIKit

// MARK: - Weight Identifiable

extension Weight: Identifiable {
    var id: PersistentIdentifier { persistentModelID }
}

// MARK: - Weight List

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
            .map { key, value in (date: key, records: value) }
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
            EditWeightSheet(record: record)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Экспорт PDF", isPresented: $showExportDialog, titleVisibility: .visible) {
            Button("За 7 дней")  { exportPDF(period: 7) }
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

    // MARK: - PDF Export

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
            let bodyAttrs:  [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
            let rowAttrs:   [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)]

            ("Отчёт по весу" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += 28
            ("Сформировано: \(DateFormatter.russianDateTime.string(from: Date()))" as NSString)
                .draw(in: CGRect(x: margin, y: y, width: pageRect.width - 2 * margin, height: 20), withAttributes: bodyAttrs)
            y += 32

            let contentWidth = pageRect.width - 2 * margin
            let dateWidth    = contentWidth * 0.5
            let valWidth     = contentWidth * 0.5
            let rowH: CGFloat = 16

            ("Дата и время" as NSString).draw(in: CGRect(x: margin, y: y, width: dateWidth, height: rowH), withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)])
            ("Вес (кг)"     as NSString).draw(in: CGRect(x: margin + dateWidth, y: y, width: valWidth, height: rowH), withAttributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold)])
            y += rowH + 2

            for record in filtered {
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

// MARK: - Add Weight Sheet

struct AddWeightSheet: View {
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
                    weightPickerCard
                    dateCard
                }
                .padding(16)
            }
            .navigationTitle("Новая запись веса")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { save() }.fontWeight(.medium) }
            }
        }
    }

    private var weightPickerCard: some View {
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
                    ForEach(20...250, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 100, height: 120)
                .clipped()

                Text(",").font(.title).padding(.horizontal, 4)

                Picker("", selection: $decimalPart) {
                    ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
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
        let kg  = Int(record.valueKg)
        let dec = Int((record.valueKg * 10).truncatingRemainder(dividingBy: 10))
        _kilograms  = State(initialValue: max(20, min(250, kg)))
        _decimalPart = State(initialValue: max(0, min(9, dec)))
        _selectedDate = State(initialValue: record.date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    weightPickerCard
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

    private var weightPickerCard: some View {
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
                    ForEach(20...250, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 100, height: 120)
                .clipped()

                Text(",").font(.title).padding(.horizontal, 4)

                Picker("", selection: $decimalPart) {
                    ForEach(0...9, id: \.self) { Text("\($0)").tag($0) }
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
        record.valueKg = Double(kilograms) + Double(decimalPart) / 10.0
        record.date    = selectedDate
        try? modelContext.save()
        dismiss()
    }
}
