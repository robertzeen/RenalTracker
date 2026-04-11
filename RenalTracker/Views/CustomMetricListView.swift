//
//  CustomMetricListView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import UIKit

struct CustomMetricListView: View {
    @Environment(\.modelContext) private var modelContext

    let metric: CustomMetric

    @State private var entryToDelete: CustomMetricEntry?
    @State private var showDeleteConfirmation = false
    @State private var isShowingAddEntry = false
    @State private var isGeneratingPDF = false

    private var sortedEntries: [CustomMetricEntry] {
        metric.entries.sorted { $0.date > $1.date }
    }

    private var groupedEntries: [(month: String, entries: [CustomMetricEntry])] {
        let grouped = Dictionary(grouping: sortedEntries) { entry in
            DateFormatter.russianMonthYear.string(from: entry.date)
        }
        return grouped
            .map { month, entries in (month: month, entries: entries) }
            .sorted { a, b in
                let dateA = sortedEntries.first {
                    DateFormatter.russianMonthYear.string(from: $0.date) == a.month
                }?.date ?? .distantPast
                let dateB = sortedEntries.first {
                    DateFormatter.russianMonthYear.string(from: $0.date) == b.month
                }?.date ?? .distantPast
                return dateA > dateB
            }
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) \(metric.unit)"
            : String(format: "%.1f \(metric.unit)", value)
    }

    // Форматирует только число, без единицы — для PDF-таблицы
    private func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    // MARK: - PDF Export

    @MainActor
    private func exportToPDF() async {
        guard !sortedEntries.isEmpty else { return }
        isGeneratingPDF = true
        defer { isGeneratingPDF = false }

        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            let margin: CGFloat = 40
            var y: CGFloat = margin

            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .bold)
            ]
            let subtitleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
            let headerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
            ]
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13)
            ]
            let footerAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.tertiaryLabel
            ]

            // Заголовок
            (metric.name as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttr)
            y += 30

            let subtitle = "Сформировано: \(DateFormatter.russianDateTime.string(from: Date()))"
            (subtitle as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttr)
            y += 20

            // Горизонтальная линия
            func drawSeparator(at lineY: CGFloat) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: lineY))
                path.addLine(to: CGPoint(x: pageRect.width - margin, y: lineY))
                UIColor.separator.setStroke()
                path.lineWidth = 0.5
                path.stroke()
            }
            drawSeparator(at: y)
            y += 16

            // Статистика
            let values = sortedEntries.map { $0.value }
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 0
            let avgVal = values.reduce(0, +) / Double(values.count)

            let statsText = "Записей: \(sortedEntries.count)  |  " +
                "Мин: \(formatNumber(minVal)) \(metric.unit)  |  " +
                "Макс: \(formatNumber(maxVal)) \(metric.unit)  |  " +
                "Среднее: \(formatNumber(avgVal)) \(metric.unit)"
            (statsText as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttr)
            y += 24

            drawSeparator(at: y)
            y += 16

            // Заголовки таблицы
            let col1: CGFloat = margin
            let col2: CGFloat = margin + 220

            ("Дата" as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: headerAttr)
            ("Значение" as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: headerAttr)
            y += 20

            // Строки таблицы
            for entry in sortedEntries {
                if y > pageRect.height - margin - 20 {
                    context.beginPage()
                    y = margin
                }
                let dateStr = DateFormatter.russianDateTime.string(from: entry.date)
                let valueStr = "\(formatNumber(entry.value)) \(metric.unit)"
                (dateStr as NSString).draw(at: CGPoint(x: col1, y: y), withAttributes: bodyAttr)
                (valueStr as NSString).draw(at: CGPoint(x: col2, y: y), withAttributes: bodyAttr)
                y += 20
            }

            // Футер
            ("Сформировано приложением RenalTracker" as NSString).draw(
                at: CGPoint(x: margin, y: pageRect.height - margin),
                withAttributes: footerAttr
            )
        }

        // Сохранить во временный файл и открыть ShareSheet
        let dateStr = DateFormatter.fileDate.string(from: Date())
        let fileName = "\(metric.name)-\(dateStr).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
        } catch {
            return
        }

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first,
            let rootVC = window.rootViewController
        else { return }

        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        rootVC.present(av, animated: true)
    }

    var body: some View {
        Group {
            if sortedEntries.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(.blue.opacity(0.4))
                    Text("Нет записей")
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Нажмите + чтобы добавить первое измерение")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(groupedEntries, id: \.month) { group in
                        Section {
                            ForEach(group.entries) { entry in
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(formatValue(entry.value))
                                            .font(.system(size: 15, weight: .medium))
                                        Text(DateFormatter.russianDateTime.string(from: entry.date))
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        entryToDelete = entry
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Удалить", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            Text(group.month.prefix(1).uppercased() + group.month.dropFirst())
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .textCase(nil)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(metric.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await exportToPDF() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 32, height: 32)
                        if isGeneratingPDF {
                            ProgressView().scaleEffect(0.7)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(isGeneratingPDF || sortedEntries.isEmpty)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddEntry = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddEntry) {
            AddCustomMetricEntrySheet(metric: metric)
                .presentationDetents([.medium, .large])
        }
        .alert("Удалить запись?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                if let entry = entryToDelete {
                    metric.entries.removeAll { $0.id == entry.id }
                    modelContext.delete(entry)
                    try? modelContext.save()
                }
                entryToDelete = nil
            }
            Button("Отмена", role: .cancel) {
                entryToDelete = nil
            }
        } message: {
            Text("Это действие нельзя отменить.")
        }
    }
}
