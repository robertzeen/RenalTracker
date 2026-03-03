//
//  DoctorVisitsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct DoctorVisitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DoctorVisit.date, order: .reverse) private var visits: [DoctorVisit]

    @State private var visitToEdit: DoctorVisit?
    @State private var visitToDelete: DoctorVisit?
    @State private var isCreatingNewVisit: Bool = false

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.locale = Locale(identifier: "ru_RU")
        return cal
    }

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }

    /// Группировка приёмов по месяцу и году, от новых к старым
    private var groupedByMonth: [(date: Date, visits: [DoctorVisit])] {
        let grouped = Dictionary(grouping: visits) { visit -> Date in
            let comps = calendar.dateComponents([.year, .month], from: visit.date)
            return calendar.date(from: comps) ?? visit.date
        }

        return grouped
            .map { (key, value) in
                let sorted = value.sorted { $0.date > $1.date }
                return (date: key, visits: sorted)
            }
            .sorted { $0.date > $1.date }
    }

    private func sectionTitle(for date: Date) -> String {
        let base = monthYearFormatter.string(from: date)
        guard let first = base.first else { return base }
        return String(first).uppercased() + base.dropFirst()
    }

    var body: some View {
        NavigationStack {
            Group {
                if visits.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "stethoscope")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.secondary)

                        Text("Здесь будет история ваших приёмов у врача")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Добавить первый приём") {
                            addNewVisit()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(groupedByMonth, id: \.date) { group in
                            Section(header: Text(sectionTitle(for: group.date))) {
                                ForEach(group.visits) { visit in
                                    Button {
                                        visitToEdit = visit
                                    } label: {
                                        DoctorVisitRow(visit: visit)
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            visitToDelete = visit
                                        } label: {
                                            Label("Удалить", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Приёмы у врача")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addNewVisit()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить приём")
                }
            }
        }
        .sheet(item: $visitToEdit, onDismiss: { isCreatingNewVisit = false }) { visit in
            DoctorVisitDetailView(visit: visit, isNewVisit: isCreatingNewVisit)
        }
        .alert(
            "Вы уверены, что хотите удалить запись?",
            isPresented: Binding(
                get: { visitToDelete != nil },
                set: { newValue in
                    if !newValue { visitToDelete = nil }
                }
            )
        ) {
            Button("Отмена", role: .cancel) {
                visitToDelete = nil
            }
            Button("Удалить", role: .destructive) {
                if let visit = visitToDelete {
                    modelContext.delete(visit)
                    try? modelContext.save()
                }
                visitToDelete = nil
            }
        }
    }

    private func addNewVisit() {
        let visit = DoctorVisit(date: Date())
        modelContext.insert(visit)
        try? modelContext.save()
        isCreatingNewVisit = true
        visitToEdit = visit
    }
}

// MARK: - Строка списка

private struct DoctorVisitRow: View {
    let visit: DoctorVisit

    private var dateText: String {
        DateFormatter.russianDateTime.string(from: visit.date)
    }

    private var doctorLine: String? {
        guard let name = visit.doctorName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }

    private var notesPreview: String {
        guard let notes = visit.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Заметок нет"
        }
        return notes
            .split(separator: "\n")
            .prefix(2)
            .joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(dateText)
                .font(.subheadline)
                .fontWeight(.semibold)

            if let doctorLine {
                Text(doctorLine)
                    .font(.subheadline)
            }

            Text(notesPreview)
                .font(.footnote)
                .foregroundStyle(
                    (visit.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        ? .secondary : .primary
                )
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

