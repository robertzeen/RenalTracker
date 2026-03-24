//
//  DoctorVisitsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct DoctorVisitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DoctorVisit.date, order: .reverse) private var visits: [DoctorVisit]

    @State private var isShowingAddVisit = false
    @State private var visitToEdit: DoctorVisit? = nil

    // MARK: - Группировка по месяцу

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: "ru_RU")
        return cal
    }

    private var groupedByMonth: [(date: Date, visits: [DoctorVisit])] {
        let grouped = Dictionary(grouping: visits) { visit -> Date in
            let comps = calendar.dateComponents([.year, .month], from: visit.date)
            return calendar.date(from: comps) ?? visit.date
        }
        return grouped
            .map { key, value in (date: key, visits: value) }
            .sorted { $0.date > $1.date }
    }

    private func sectionTitle(for date: Date) -> String {
        DateFormatter.russianMonthYear.string(from: date).uppercased()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if visits.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(groupedByMonth, id: \.date) { group in
                            Section {
                                ForEach(group.visits) { visit in
                                    visitRow(visit)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                modelContext.delete(visit)
                                                try? modelContext.save()
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                }
                            } header: {
                                Text(sectionTitle(for: group.date))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Приёмы у врача")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingAddVisit = true
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
        }
        .sheet(isPresented: $isShowingAddVisit) {
            AddDoctorVisitView()
        }
        .sheet(item: $visitToEdit) { visit in
            AddDoctorVisitView(existingVisit: visit)
        }
    }

    // MARK: - Строка записи

    @ViewBuilder
    private func visitRow(_ visit: DoctorVisit) -> some View {
        Button {
            visitToEdit = visit
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Text("👩‍⚕️")
                        .font(.callout)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.doctorName ?? "Без врача")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)

                    Text(DateFormatter.russianDateTime.string(from: visit.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let notes = visit.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .padding(.top, 2)
                    } else {
                        Text("Заметок нет")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Пустой экран

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Text("🏥")
                    .font(.system(size: 36))
            }
            Text("Нет записей о приёмах")
                .font(.headline)
                .foregroundStyle(.primary)
            Text("Здесь будет история ваших\nприёмов у врача")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                isShowingAddVisit = true
            } label: {
                Text("Добавить первый приём")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}
