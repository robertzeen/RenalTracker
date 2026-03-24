//
//  HomeView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import EventKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingDoctorDateSheet = false
    @State private var isShowingLabTestDateSheet = false
    @State private var isShowingSettings = false

    @State private var currentTime = Date()
    @State private var refreshTimer: Timer?

    @Query private var profiles: [UserProfile]
    @Query(sort: \BloodPressure.date, order: .reverse) private var bloodPressureRecords: [BloodPressure]
    @Query(sort: \Weight.date, order: .reverse) private var weightRecords: [Weight]
    @Query(sort: \Medication.name, order: .forward) private var medications: [Medication]
    @Query(sort: \MedicationIntake.date, order: .forward) private var intakes: [MedicationIntake]

    var onShowMedications: (() -> Void)?
    var onShowDoctorVisits: (() -> Void)?

    init(
        onShowMedications: (() -> Void)? = nil,
        onShowDoctorVisits: (() -> Void)? = nil
    ) {
        self.onShowMedications = onShowMedications
        self.onShowDoctorVisits = onShowDoctorVisits
    }

    // MARK: - Вычисляемые свойства профиля

    private var currentProfile: UserProfile? { profiles.first }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        default: return "Добрый вечер"
        }
    }

    private var statusText: String? {
        guard let profile = currentProfile else { return nil }
        switch profile.category {
        case .postTransplant:
            if let date = profile.transplantDate, let days = daysSince(date) {
                return "🌱 День \(days) после трансплантации"
            }
        case .hemodialysis:
            if let date = profile.hemoStartDate, let days = daysSince(date) {
                return "💉 День \(days) на гемодиализе"
            }
        case .peritonealDialysis:
            if let date = profile.pdStartDate, let days = daysSince(date) {
                return "💧 День \(days) на перитонеальном диализе"
            }
        }
        return nil
    }

    private var displayName: String {
        if let profile = currentProfile, !profile.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return profile.name
        }
        return "друг"
    }

    private var latestBloodPressure: BloodPressure? { bloodPressureRecords.first }
    private var latestWeight: Weight? { weightRecords.first }

    var todayQuote: DailyQuote {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return allQuotes[dayOfYear % allQuotes.count]
    }

    // MARK: - Расписание лекарств

    private var calendar: Calendar { Calendar.current }
    private var todayStart: Date { calendar.startOfDay(for: Date()) }
    private var todayEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(86400)
    }
    private var todayWeekday: Int { calendar.component(.weekday, from: Date()) }

    private var todaysMedications: [Medication] {
        medications.filter { $0.isActive && $0.daysOfWeek.contains(todayWeekday) }
    }

    private var todayScheduleGroups: [(time: Date, medications: [Medication])] {
        let grouped = Dictionary(grouping: todaysMedications) { med -> Date in
            let comps = calendar.dateComponents([.hour, .minute], from: med.time)
            return calendar.date(from: comps) ?? med.time
        }
        return grouped
            .map { key, value in (time: key, medications: value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) }
            .sorted { $0.time < $1.time }
    }

    private var allMedicationsForTodayTaken: Bool {
        guard !todayScheduleGroups.isEmpty else { return false }
        return todayScheduleGroups.allSatisfy { group in
            group.medications.allSatisfy { intakeForToday(medication: $0)?.isTaken == true }
        }
    }

    private var nextUpcomingGroup: (time: Date, medications: [Medication])? {
        let now = Date()
        return todayScheduleGroups.first { group in
            group.time > now &&
            !group.medications.allSatisfy { intakeForToday(medication: $0)?.isTaken == true }
        }
    }

    // MARK: - Статус события

    private enum EventStatus: Equatable {
        case passed, today, tomorrow
        case upcoming(days: Int)
    }

    private func eventStatus(for date: Date) -> EventStatus {
        let now = currentTime
        if now > date.addingTimeInterval(3600) { return .passed }
        let diffDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        switch diffDays {
        case 0: return .today
        case 1: return .tomorrow
        default: return .upcoming(days: diffDays)
        }
    }

    @ViewBuilder
    private func eventBadge(for date: Date) -> some View {
        switch eventStatus(for: date) {
        case .passed:
            Text("Прошёл")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemGray5))
                .cornerRadius(10)
        case .today:
            Text("Сегодня!")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
        case .tomorrow:
            Text("Завтра!")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(10)
        case .upcoming(let days):
            Text("Через \(days) дней")
                .font(.system(size: 11))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    greetingSection
                        .padding(.vertical, 4)
                    metricsSection
                        .padding(.vertical, 4)
                    medicationsTodaySection
                        .padding(.vertical, 4)
                    eventsSection
                        .padding(.vertical, 4)
                    quoteSection
                        .padding(.vertical, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { isShowingSettings = true } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.secondarySystemBackground))
                                .frame(width: 32, height: 32)
                            Image(systemName: "gearshape")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Настройки")
                }
            }
        }
        .sheet(isPresented: $isShowingDoctorDateSheet) {
            DoctorAppointmentSheet(userProfile: currentProfile)
        }
        .sheet(isPresented: $isShowingLabTestDateSheet) {
            LabTestSheet(userProfile: currentProfile)
        }
        .sheet(isPresented: $isShowingSettings) {
            if let profile = currentProfile {
                SettingsView(profile: profile, onDismiss: { isShowingSettings = false })
            }
        }
        .onAppear {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
            NotificationManager.shared.printScheduledNotifications()
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Приветствие

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(greetingText), \(displayName)!")
                .font(.title2)
                .fontWeight(.bold)
            if let status = statusText {
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Показатели

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Последние показатели")
                .font(.headline)
            HStack(spacing: 12) {
                metricCard(
                    title: "Давление",
                    valueText: latestBloodPressureValueText,
                    dateText: latestBloodPressureDateText,
                    hasData: latestBloodPressure != nil
                )
                metricCard(
                    title: "Вес",
                    valueText: latestWeightValueText,
                    dateText: latestWeightDateText,
                    hasData: latestWeight != nil
                )
            }
        }
    }

    private func metricCard(title: String, valueText: String, dateText: String, hasData: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if hasData {
                Text(valueText)
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(dateText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Пока нет данных.\nМожно добавить на вкладке «Показатели».")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Лекарства

    private var medicationsTodaySection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Лекарства на сегодня")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            .padding(14)

            Divider()

            if medications.isEmpty {
                Text("Лекарства ещё не добавлены. Настройте приём во вкладке «Лекарства».")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else if todayScheduleGroups.isEmpty {
                Text("На сегодня приёмов не запланировано.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
            } else if allMedicationsForTodayTaken {
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
                ForEach(Array(todayScheduleGroups.enumerated()), id: \.element.time) { index, group in
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
        let allTaken = group.medications.allSatisfy { intakeForToday(medication: $0)?.isTaken == true }
        let isNext = nextUpcomingGroup?.time == group.time

        HStack {
            Text("\(timeString) — \(names)")
                .font(isNext ? .system(size: 14, weight: .medium) : .system(size: 14))
                .foregroundStyle(allTaken ? .secondary : .primary)
            Spacer()
            if allTaken {
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

    // MARK: - Ближайшие события

    private var eventsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Ближайшие события")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                if onShowDoctorVisits != nil {
                    Button("Журнал →") { onShowDoctorVisits?() }
                        .font(.system(size: 13))
                        .foregroundStyle(.blue)
                }
            }
            .padding(14)

            Divider()

            doctorEventRow

            Divider()

            labEventRow
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var doctorEventRow: some View {
        let appointment = currentProfile?.nextDoctorAppointment
        let name = currentProfile?.nextDoctorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = (name?.isEmpty == false ? name : nil) ?? "Приём у врача"

        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("👩‍⚕️")
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.system(size: 14, weight: .medium))
                if let appt = appointment {
                    Text(DateFormatter.russianDateTime.string(from: appt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Дата не указана")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let appt = appointment {
                eventBadge(for: appt)
            }
            Button { isShowingDoctorDateSheet = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private var labEventRow: some View {
        let labDate = currentProfile?.nextLabTest

        return HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 36, height: 36)
                Text("🧪")
                    .font(.system(size: 16))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Сдача анализов")
                    .font(.system(size: 14, weight: .medium))
                if let lab = labDate {
                    Text(DateFormatter.russianDateTime.string(from: lab))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    Text("Дата не указана")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let lab = labDate {
                eventBadge(for: lab)
            }
            Button { isShowingLabTestDateSheet = true } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    // MARK: - Цитата

    private var quoteSection: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color.blue.opacity(0.6))
                .frame(width: 3)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 6) {
                Text(todayQuote.text)
                    .font(.system(size: 14))
                    .italic()
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                if let author = todayQuote.author {
                    Text("— \(author)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Вспомогательные свойства

    private var latestBloodPressureValueText: String {
        guard let bp = latestBloodPressure else { return "" }
        return "\(bp.systolic)/\(bp.diastolic)"
    }

    private var latestBloodPressureDateText: String {
        guard let bp = latestBloodPressure else { return "" }
        return DateFormatter.russianDateTime.string(from: bp.date)
    }

    private var latestWeightValueText: String {
        guard let w = latestWeight else { return "" }
        let value = w.valueKg
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value)) кг"
        } else {
            return "\(value) кг"
        }
    }

    private var latestWeightDateText: String {
        guard let w = latestWeight else { return "" }
        return DateFormatter.russianDateTime.string(from: w.date)
    }

    private func daysSince(_ date: Date) -> Int? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        let components = Calendar.current.dateComponents([.day], from: startOfDay, to: today)
        guard let days = components.day, days >= 0 else { return nil }
        return days + 1
    }

    // MARK: - Приём лекарств

    private func intakeForToday(medication: Medication) -> MedicationIntake? {
        intakes.first { intake in
            intake.medication == medication &&
            intake.date >= todayStart &&
            intake.date < todayEnd
        }
    }

    private func toggleTaken(for medication: Medication) {
        if let existing = intakeForToday(medication: medication) {
            if existing.isTaken {
                modelContext.delete(existing)
            } else {
                existing.isTaken = true
            }
        } else {
            let intake = MedicationIntake(date: Date(), isTaken: true, medication: medication)
            modelContext.insert(intake)
        }
        try? modelContext.save()
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [UserProfile.self, BloodPressure.self, Weight.self, Medication.self, MedicationIntake.self], inMemory: true)
}
