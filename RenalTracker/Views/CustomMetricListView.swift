//
//  CustomMetricListView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct CustomMetricListView: View {
    @Environment(\.modelContext) private var modelContext

    let metric: CustomMetric

    @State private var entryToDelete: CustomMetricEntry?
    @State private var showDeleteConfirmation = false
    @State private var isShowingAddEntry = false

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
