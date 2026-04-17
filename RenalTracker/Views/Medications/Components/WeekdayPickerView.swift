//
//  WeekdayPickerView.swift
//  RenalTracker
//

import SwiftUI

struct WeekdayOption: Identifiable {
    let id: Int
    let shortTitle: String
}

let allWeekdayOptions: [WeekdayOption] = [
    .init(id: 2, shortTitle: "Пн"),
    .init(id: 3, shortTitle: "Вт"),
    .init(id: 4, shortTitle: "Ср"),
    .init(id: 5, shortTitle: "Чт"),
    .init(id: 6, shortTitle: "Пт"),
    .init(id: 7, shortTitle: "Сб"),
    .init(id: 1, shortTitle: "Вс")
]

struct WeekdayPickerView: View {
    @Binding var selectedDays: Set<Int>

    private var allDayIDs: Set<Int> { Set(allWeekdayOptions.map { $0.id }) }
    private var isEveryday: Bool { selectedDays == allDayIDs }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(allWeekdayOptions) { option in
                    let isSelected = selectedDays.contains(option.id)
                    Button { toggleDay(option.id) } label: {
                        Text(option.shortTitle)
                            .font(.subheadline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                selectedDays = isEveryday ? [] : allDayIDs
            } label: {
                Text("Ежедневно")
                    .font(.subheadline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isEveryday ? Color.accentColor.opacity(0.2) : Color(.systemGray6))
                    )
            }
            .buttonStyle(.plain)

            if selectedDays.isEmpty {
                Text("Выберите хотя бы один день.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleDay(_ weekday: Int) {
        if selectedDays.contains(weekday) {
            selectedDays.remove(weekday)
        } else {
            selectedDays.insert(weekday)
        }
    }
}
