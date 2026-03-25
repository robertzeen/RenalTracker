//
//  MedicationScheduleComponents.swift
//  RenalTracker — общие строки расписания (главный экран и вкладка «Лекарства»).
//

import SwiftData
import SwiftUI

enum MedicationScheduleCopy {
    static let noScheduledToday = "На сегодня приёмов не запланировано."
}

enum MedicationScheduleFormat {
    static func timeString(for time: Date) -> String {
        time.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "ru_RU"))
        )
    }

    static func dosageCaption(for med: Medication) -> String {
        let formatted = med.formattedDosage
        return formatted.isEmpty ? "Дозировка не указана" : formatted
    }
}

// MARK: - Прогресс «Принято сегодня»

struct MedicationTodayProgressCard: View {
    let takenCount: Int
    let totalCount: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ПРИНЯТО СЕГОДНЯ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(takenCount) из \(totalCount)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(totalCount > 0 && takenCount == totalCount
                            ? Color.green : Color.blue)
                        .frame(
                            width: totalCount > 0
                                ? geometry.size.width * CGFloat(takenCount) / CGFloat(totalCount)
                                : 0,
                            height: 6
                        )
                        .animation(.easeInOut, value: takenCount)
                }
            }
            .frame(height: 6)

            if takenCount == totalCount && totalCount > 0 {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    Text("Все лекарства приняты")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Заголовок слота по времени

struct MedicationTimeSlotHeader: View {
    let time: Date

    var body: some View {
        HStack(spacing: 3) {
            Text(MedicationScheduleFormat.timeString(for: time))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
        }
//        .padding(.horizontal, 0)
    }
}

// MARK: - Строка лекарства (чекбокс через onTapGesture)

struct MedicationScheduleRow: View {
    let medication: Medication
    let isTaken: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            VStack(alignment: .leading, spacing: 3) {
                Text(medication.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(MedicationScheduleFormat.dosageCaption(for: medication))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .stroke(isTaken ? Color.green : Color(.separator), lineWidth: 1.5)
                    .frame(width: 26, height: 26)
                if isTaken {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
            .contentShape(Circle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    onToggle()
                }
            }
            .accessibilityLabel(isTaken ? "Лекарство принято" : "Отметить приём лекарства")
            .accessibilityAddTraits(.isButton)
        }
        .padding()
    }
}
