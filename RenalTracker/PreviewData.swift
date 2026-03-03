//
//  PreviewData.swift
//  RenalTracker
//

import Foundation
import SwiftData

struct PreviewData {

    static func loadTestData(into modelContext: ModelContext) {
        let calendar = Calendar.current
        let now = Date()

        generateBloodPressure(into: modelContext, calendar: calendar, now: now)
        generateWeight(into: modelContext, calendar: calendar, now: now)
        generateLabResults(into: modelContext, calendar: calendar, now: now)
        generateMedications(into: modelContext, calendar: calendar, now: now)

        try? modelContext.save()
    }

    // MARK: - Blood Pressure

    private static func generateBloodPressure(into context: ModelContext, calendar: Calendar, now: Date) {
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }

            let date = randomTime(on: day, calendar: calendar, hourRange: 7...20)

            let systolic = Int.random(in: 120...160)
            let diastolicUpper = min(100, systolic - 20)
            let diastolicLower = max(75, diastolicUpper - 15)
            let diastolic = Int.random(in: diastolicLower...diastolicUpper)

            let pulse = Int.random(in: 60...95)

            let record = BloodPressure(
                systolic: systolic,
                diastolic: diastolic,
                pulse: pulse,
                date: date
            )
            context.insert(record)
        }
    }

    // MARK: - Weight

    private static func generateWeight(into context: ModelContext, calendar: Calendar, now: Date) {
        var currentWeight: Double = 75.0

        // Идём от старых значений к более новым, чтобы колебания были плавными
        for offset in (0..<30).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }

            currentWeight += Double.random(in: -0.3...0.3)
            currentWeight = min(77.0, max(74.0, currentWeight))

            let date = randomTime(on: day, calendar: calendar, hourRange: 6...10)

            let record = Weight(
                valueKg: currentWeight,
                date: date
            )
            context.insert(record)
        }
    }

    // MARK: - Lab Results

    private static func generateLabResults(into context: ModelContext, calendar: Calendar, now: Date) {
        let configs: [(name: String, unit: String, range: ClosedRange<Double>)] = [
            ("Креатинин", "мкмоль/л", 60.0...120.0),
            ("Гемоглобин", "г/л", 110.0...140.0),
            ("Калий", "ммоль/л", 3.5...5.5)
        ]

        for index in 0..<10 {
            let config = configs[index % configs.count]
            // Анализы примерно раз в 3 дня
            guard let day = calendar.date(byAdding: .day, value: -index * 3, to: now) else { continue }
            let date = randomTime(on: day, calendar: calendar, hourRange: 7...11)

            let mid = (config.range.lowerBound + config.range.upperBound) / 2
            let spread = (config.range.upperBound - config.range.lowerBound) / 4
            let value = mid + Double.random(in: -spread...spread)
            let clampedValue = min(config.range.upperBound, max(config.range.lowerBound, value))

            let result = LabResult(
                name: config.name,
                value: clampedValue,
                unit: config.unit,
                date: date
            )
            context.insert(result)
        }
    }

    // MARK: - Medications

    private static func generateMedications(into context: ModelContext, calendar: Calendar, now: Date) {
        // Дни недели по Calendar: 1 - воскресенье, 2 - понедельник, ... 7 - суббота
        let weekdaysAll = Array(1...7)
        let weekdaysWork = [2, 3, 4, 5, 6] // Пн-Пт

        func time(hour: Int, minute: Int) -> Date {
            var comps = DateComponents()
            comps.year = 2000
            comps.month = 1
            comps.day = 1
            comps.hour = hour
            comps.minute = minute
            return calendar.date(from: comps) ?? Date()
        }

        let meds: [(String, Double?, String, [Int], Int, Int)] = [
            ("Такролимус", 1.0, "мг", weekdaysAll, 8, 0),
            ("Микофенолат мофетил", 500.0, "мг", weekdaysAll, 9, 0),
            ("Преднизолон", 5.0, "мг", weekdaysWork, 8, 30),
            ("Амлодипин", 5.0, "мг", weekdaysAll, 20, 0)
        ]

        for (name, amount, unit, days, hour, minute) in meds {
            let med = Medication(
                name: name,
                dosageAmount: amount,
                dosageUnit: unit,
                daysOfWeek: days,
                time: time(hour: hour, minute: minute),
                isActive: true
            )
            context.insert(med)
        }
    }

    // MARK: - Helpers

    private static func randomTime(on day: Date, calendar: Calendar, hourRange: ClosedRange<Int>) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = Int.random(in: hourRange)
        components.minute = [0, 15, 30, 45].randomElement() ?? 0
        return calendar.date(from: components) ?? day
    }
}

