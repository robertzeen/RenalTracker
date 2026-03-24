//
//  HomeMedicationsView.swift
//  RenalTracker
//

import SwiftUI

struct HomeMedicationsView: View {
    let hasMedications: Bool
    let groups: [(time: Date, medications: [Medication])]
    let allTaken: Bool
    let nextUpcomingGroup: (time: Date, medications: [Medication])?
    /// Returns true if the medication's intake for today is marked as taken
    let isTaken: (Medication) -> Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Лекарства на сегодня")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            .padding(14)

            Divider()

            if !hasMedications {
                Text("Лекарства ещё не добавлены. Настройте приём во вкладке «Лекарства».")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else if groups.isEmpty {
                Text("На сегодня приёмов не запланировано.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else if allTaken {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Все лекарства на сегодня приняты!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
            } else {
                ForEach(Array(groups.enumerated()), id: \.element.time) { index, group in
                    if index > 0 {
                        Divider().padding(.leading, 14)
                    }
                    medicationSlotRow(for: group)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func medicationSlotRow(for group: (time: Date, medications: [Medication])) -> some View {
        let timeString = group.time.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "ru_RU"))
        )
        let names = group.medications.map { $0.name }.joined(separator: ", ")
        let allGroupTaken = group.medications.allSatisfy { isTaken($0) }
        let isNext = nextUpcomingGroup?.time == group.time

        HStack {
            Text("\(timeString) — \(names)")
                .font(isNext ? .system(size: 14, weight: .medium) : .system(size: 14))
                .foregroundStyle(allGroupTaken ? .secondary : .primary)
            Spacer()
            if allGroupTaken {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
            } else if isNext {
                Text("Ожидает")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
            }
        }
        .padding(14)
    }
}
