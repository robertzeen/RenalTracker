//
//  CustomMetricListView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct CustomMetricListView: View {
    @Environment(\.modelContext) private var modelContext

    let metric: CustomMetric

    @Query private var profiles: [UserProfile]

    @State private var entryToDelete: CustomMetricEntry?
    @State private var showDeleteConfirmation = false
    @State private var isShowingAddEntry = false
    @State private var pdfURL: URL?
    @State private var isSharePresented = false
    @State private var isGeneratingPDF = false
    @State private var isShowingNoDataAlert = false

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

    private var patientDisplayName: String? {
        guard let profile = profiles.first else { return nil }
        var parts = [profile.name]
        if let last = profile.lastName { parts.append(last) }
        return parts.joined(separator: " ")
    }

    private func formatValue(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) \(metric.unit)"
            : String(format: "%.1f \(metric.unit)", value)
    }

    // MARK: - PDF Export

    @MainActor
    private func exportToPDF() {
        guard !sortedEntries.isEmpty else { isShowingNoDataAlert = true; return }
        isGeneratingPDF = true

        // Извлекаем все данные из @Model на главном потоке до Task.detached
        let metricName   = metric.name
        let unit         = metric.unit
        let name         = patientDisplayName
        let filePrefix   = metric.name
        let snapshot: [CustomMetricPDFExporter.Entry] = sortedEntries.map {
            .init(date: $0.date, value: $0.value)
        }

        Task.detached(priority: .userInitiated) {
            let data = CustomMetricPDFExporter.makeData(
                metricName: metricName,
                unit: unit,
                entries: snapshot,
                patientName: name
            )
            let url = try? PDFExporter.saveToTempFile(data: data, fileNamePrefix: filePrefix)
            await MainActor.run {
                isGeneratingPDF = false
                if let url {
                    pdfURL = url
                    isSharePresented = true
                }
            }
        }
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
                    exportToPDF()
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
        .sheet(isPresented: $isSharePresented) {
            if let url = pdfURL {
                ShareSheet(activityItems: [url])
            }
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
        .alert("Нет данных за выбранный период", isPresented: $isShowingNoDataAlert) {
            Button("Закрыть", role: .cancel) { }
        } message: {
            Text("Добавьте записи или выберите другой период для экспорта.")
        }
    }
}
