//
//  MedicationScheduleCalculator.swift
//  RenalTracker
//
//  Чистый value-type для расчёта расписания лекарств на сегодня.
//  Не зависит от SwiftUI и @Environment — пересоздаётся при каждом body.
//  Принимает инъекцию `now` и `calendar` для тестируемости.
//

import Foundation

struct MedicationScheduleCalculator {

    let medications: [Medication]
    let intakes: [MedicationIntake]
    let now: Date
    let calendar: Calendar

    init(
        medications: [Medication],
        intakes: [MedicationIntake],
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.medications = medications
        self.intakes = intakes
        self.now = now
        self.calendar = calendar
    }

    // MARK: - Private

    private var todayStart: Date {
        calendar.startOfDay(for: now)
    }

    private var todayEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(86400)
    }

    private var todayWeekday: Int {
        calendar.component(.weekday, from: now)
    }

    // MARK: - Public

    var todaysMedications: [Medication] {
        medications.filter { $0.isActive && $0.daysOfWeek.contains(todayWeekday) }
    }

    var todayScheduleGroups: [(time: Date, medications: [Medication])] {
        let grouped = Dictionary(grouping: todaysMedications) { med -> Date in
            let comps = calendar.dateComponents([.hour, .minute], from: med.time)
            return calendar.date(from: comps) ?? med.time
        }
        return grouped
            .map { key, value in
                let sortedMeds = value.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return (time: key, medications: sortedMeds)
            }
            .sorted { $0.time < $1.time }
    }

    func intakeForToday(for medication: Medication) -> MedicationIntake? {
        intakes.first { intake in
            intake.medication == medication &&
            intake.date >= todayStart &&
            intake.date < todayEnd
        }
    }

    func isTaken(_ medication: Medication) -> Bool {
        intakeForToday(for: medication)?.isTaken == true
    }

    var takenCount: Int {
        todaysMedications.filter { isTaken($0) }.count
    }

    var totalCount: Int {
        todaysMedications.count
    }

    var allTaken: Bool {
        !todayScheduleGroups.isEmpty &&
        todayScheduleGroups.allSatisfy { group in
            group.medications.allSatisfy { isTaken($0) }
        }
    }

    var nextUpcomingGroup: (time: Date, medications: [Medication])? {
        todayScheduleGroups.first { group in
            group.time > now &&
            !group.medications.allSatisfy { isTaken($0) }
        }
    }
}
