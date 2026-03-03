//
//  HomeView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var isShowingDoctorDateSheet = false
    @State private var doctorAppointmentDatePicker: Date = Date()

    @State private var isShowingLabTestDateSheet = false
    @State private var labTestDatePicker: Date = Date()

    @State private var doctorAppointmentDoctorName: String = ""

    @Query private var profiles: [UserProfile]
    @Query(sort: \BloodPressure.date, order: .reverse) private var bloodPressureRecords: [BloodPressure]
    @Query(sort: \Weight.date, order: .reverse) private var weightRecords: [Weight]
    @Query(sort: \Medication.name, order: .forward) private var medications: [Medication]
    @Query(sort: \MedicationIntake.date, order: .forward) private var intakes: [MedicationIntake]

    /// Опциональный колбэк для переключения на вкладку «Лекарства»
    var onShowMedications: (() -> Void)?

    init(onShowMedications: (() -> Void)? = nil) {
        self.onShowMedications = onShowMedications
    }

    private var currentProfile: UserProfile? {
        profiles.first
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Доброе утро"
        case 12..<18:
            return "Добрый день"
        default:
            return "Добрый вечер"
        }
    }

    private var statusText: String? {
        guard let profile = currentProfile else { return nil }

        switch profile.category {
        case .postTransplant:
            if let date = profile.transplantDate,
               let days = daysSince(date) {
                return "🌱 День \(days) после трансплантации"
            }
        case .hemodialysis:
            if let date = profile.hemoStartDate,
               let days = daysSince(date) {
                return "💉 День \(days) на гемодиализе"
            }
        case .peritonealDialysis:
            if let date = profile.pdStartDate,
               let days = daysSince(date) {
                return "💧 День \(days) на перитонеальном диализе"
            }
        }
        return nil
    }

    private var displayName: String {
        if let profile = currentProfile, !profile.name.trimmingCharacters(in: .whitespaces).isEmpty {
            return profile.name
        } else {
            return "друг"
        }
    }

    private var latestBloodPressure: BloodPressure? {
        bloodPressureRecords.first
    }

    private var latestWeight: Weight? {
        weightRecords.first
    }

    private var dailyQuote: (text: String, author: String) {
        let quotes: [(String, String)] = [
            ("Даже маленький шаг вперёд — это движение к цели.", "Неизвестный автор"),
            ("Сила духа измеряется не отсутствием боли, а умением идти дальше несмотря на неё.", "Неизвестный автор"),
            ("Каждый новый день — шанс позаботиться о себе чуть лучше, чем вчера.", "Неизвестный автор"),
            ("Ты сильнее, чем думаешь, и важнее, чем представляешь.", "Неизвестный автор"),
            ("Здоровье — это путь, а не пункт назначения. Главное — не останавливаться.", "Неизвестный автор"),
            ("Иногда самое большое мужество — просто продолжать жить и лечиться.", "Неизвестный автор"),
            ("Помощь принимать так же важно, как и помогать другим.", "Неизвестный автор"),
            ("Каждый анализ — это не приговор, а подсказка, как двигаться дальше.", "Неизвестный автор"),
            ("Твоё тело борется каждый день. Дай ему поддержку и терпение.", "Неизвестный автор"),
            ("Надежда — это тишина внутри, которая шепчет: ‘Мы справимся’.", "Неизвестный автор"),
            ("Иногда прогресс незаметен, но он есть в каждом дне, когда ты не сдаёшься.", "Неизвестный автор"),
            ("Слабость — не признак поражения, а знак того, что ты долго был силой для других.", "Неизвестный автор"),
            ("Даже самые тяжёлые дни когда‑нибудь остаются позади.", "Неизвестный автор"),
            ("Ты имеешь право на усталость, но не обязан сдаваться.", "Неизвестный автор"),
            ("Забота о себе — это не эгоизм, а необходимость.", "Неизвестный автор"),
            ("Иногда главное достижение дня — то, что ты прожил этот день.", "Неизвестный автор"),
            ("Слушай своё тело: оно не враг, а партнёр в этой дороге.", "Неизвестный автор"),
            ("Шаг за шагом, день за днём — так и строится новая жизнь.", "Неизвестный автор"),
            ("Болезнь меняет многое, но она не забирает твою ценность как человека.", "Неизвестный автор"),
            ("Важны не темпы, а направление движения.", "Неизвестный автор"),
            ("Иногда самое смелое решение — попросить о помощи.", "Неизвестный автор"),
            ("Твоё тело восстанавливается медленно, но уверенно — доверься процессу.", "Неизвестный автор"),
            ("Даже если сегодня сил мало, это не отменяет твоей внутренней силы.", "Неизвестный автор"),
            ("Каждый вдох — напоминание: ты всё ещё здесь и продолжаешь путь.", "Неизвестный автор"),
            ("Пусть забота о здоровье станет проявлением любви к себе.", "Неизвестный автор"),
            ("Бывают дни, когда достаточно просто быть. Этого уже много.", "Неизвестный автор"),
            ("Даже если мир сузился до анализов и таблеток, за его пределами всё ещё есть жизнь.", "Неизвестный автор"),
            ("Доверяй врачам, но не забывай слушать себя.", "Неизвестный автор"),
            ("Каждый прожитый день с болезнью — это ещё один день твоей победы.", "Неизвестный автор"),
            ("Твоё сердце бьётся — а значит, надежда жива.", "Неизвестный автор")
        ]

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = (dayOfYear - 1) % quotes.count
        return quotes[index]
    }

    // MARK: - Календарь и расписание лекарств

    private var calendar: Calendar { Calendar.current }

    private var todayStart: Date { calendar.startOfDay(for: Date()) }

    private var todayEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart.addingTimeInterval(24 * 60 * 60)
    }

    private var todayWeekday: Int {
        calendar.component(.weekday, from: Date())
    }

    /// Активные лекарства, которые должны быть приняты сегодня
    private var todaysMedications: [Medication] {
        medications.filter { $0.isActive && $0.daysOfWeek.contains(todayWeekday) }
    }

    /// Группы лекарств по времени приёма (от раннего к позднему)
    private var todayScheduleGroups: [(time: Date, medications: [Medication])] {
        let grouped = Dictionary(grouping: todaysMedications) { med -> Date in
            let comps = calendar.dateComponents([.hour, .minute], from: med.time)
            return calendar.date(from: comps) ?? med.time
        }

        return grouped
            .map { (key, value) in
                let sortedMeds = value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                return (time: key, medications: sortedMeds)
            }
            .sorted { $0.time < $1.time }
    }

    /// Все ли приёмы на сегодня приняты
    private var allMedicationsForTodayTaken: Bool {
        guard !todayScheduleGroups.isEmpty else { return false }
        return todayScheduleGroups.allSatisfy { group in
            group.medications.allSatisfy { intakeForToday(medication: $0)?.isTaken == true }
        }
    }

    /// Ближайший предстоящий приём, у которого ещё не все лекарства отмечены
    private var nextUpcomingGroup: (time: Date, medications: [Medication])? {
        let now = Date()
        return todayScheduleGroups.first { group in
            group.time > now &&
            !group.medications.allSatisfy { intakeForToday(medication: $0)?.isTaken == true }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                greetingSection
                    .padding(.vertical, 4)
                metricsSection
                    .padding(.vertical, 4)
                medicationsTodaySection
                    .padding(.vertical, 4)
                doctorAppointmentSection
                    .padding(.vertical, 4)
                labTestSection
                    .padding(.vertical, 4)
                quoteSection
                    .padding(.vertical, 4)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(isPresented: $isShowingDoctorDateSheet) {
            doctorAppointmentDateSheet
        }
        .sheet(isPresented: $isShowingLabTestDateSheet) {
            labTestDateSheet
        }
    }

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

    // MARK: - Лекарства сегодня

    private var medicationsTodaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Лекарства на сегодня")
                    .font(.headline)
            }

            if medications.isEmpty {
                Text("Лекарства ещё не добавлены. Настройте приём во вкладке \"Лекарства\".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if todayScheduleGroups.isEmpty {
                Text("На сегодня приёмов не запланировано.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if allMedicationsForTodayTaken {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🎉 Все лекарства на сегодня приняты!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                if let next = nextUpcomingGroup {
                    nextIntakeCard(for: next)
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(todayScheduleGroups.enumerated()), id: \.element.time) { index, group in
                        if nextUpcomingGroup?.time != group.time {
                            if index > 0 {
                                Divider()
                            }
                            medicationsLine(for: group)
                                .padding(.vertical, 6)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // MARK: - Приём у врача

    private var doctorAppointmentSection: some View {
        let appointment = currentProfile?.nextDoctorAppointment
        let doctorName = currentProfile?.nextDoctorName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let appointmentStart = appointment.map { calendar.startOfDay(for: $0) }
        let isPast = appointmentStart.map { $0 < todayStart } ?? true

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Следующий приём у врача")
                    .font(.headline)
            }

            if appointment == nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Запись к нефрологу не указана")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        doctorAppointmentDatePicker = Date()
                        doctorAppointmentDoctorName = currentProfile?.nextDoctorName ?? ""
                        isShowingDoctorDateSheet = true
                    } label: {
                        Text("Добавить +")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isPast {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Приём прошёл")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        doctorAppointmentDatePicker = Date()
                        doctorAppointmentDoctorName = currentProfile?.nextDoctorName ?? ""
                        isShowingDoctorDateSheet = true
                    } label: {
                        Text("Обновить дату")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(0.85)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Text("🏥")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Приём у нефролога")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let name = doctorName, !name.isEmpty {
                            Text("👨‍⚕️ \(name)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let d = appointment {
                            Text(DateFormatter.russianDateTime.string(from: d))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        doctorAppointmentSubtitle(appointmentStart: appointmentStart!)
                    }
                    Spacer()
                    Button {
                        doctorAppointmentDatePicker = appointment ?? Date()
                        doctorAppointmentDoctorName = currentProfile?.nextDoctorName ?? ""
                        isShowingDoctorDateSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(appointment != nil && isPast ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func doctorAppointmentSubtitle(appointmentStart: Date) -> some View {
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        if appointmentStart == todayStart {
            Text("Сегодня!")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        } else if appointmentStart == tomorrowStart {
            Text("Завтра!")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)
        } else {
            let days = (calendar.dateComponents([.day], from: todayStart, to: appointmentStart).day ?? 0)
            Text("Через \(days) \(days == 1 ? "день" : days < 5 ? "дня" : "дней")")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var doctorAppointmentDateSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ФИО врача (опционально)")
                        .font(.subheadline)
                    TextField("Например: Иванов Иван Иванович", text: $doctorAppointmentDoctorName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 2)

                DatePicker(
                    "Дата и время приёма",
                    selection: $doctorAppointmentDatePicker,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.locale, Locale(identifier: "ru_RU"))
                Spacer()
            }
            .padding(20)
            .navigationTitle("Приём у врача")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isShowingDoctorDateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                            let rawName = doctorAppointmentDoctorName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let date = doctorAppointmentDatePicker

                            if rawName.isEmpty {
                                currentProfile?.nextDoctorName = nil
                            } else {
                                currentProfile?.nextDoctorName = rawName
                            }
                            currentProfile?.nextDoctorAppointment = date
                        try? modelContext.save()
                        NotificationManager.shared.scheduleDoctorAppointmentNotification(date: date, doctorName: rawName.isEmpty ? nil : rawName)
                        isShowingDoctorDateSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Сдача анализов

    private var labTestSection: some View {
        let labDate = currentProfile?.nextLabTest
        let labStart = labDate.map { calendar.startOfDay(for: $0) }
        let isPast = labStart.map { $0 < todayStart } ?? true

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Следующая дата сдачи анализов")
                    .font(.headline)
            }

            if labDate == nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Не указана")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        labTestDatePicker = Date()
                        isShowingLabTestDateSheet = true
                    } label: {
                        Text("Добавить +")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isPast {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Дата прошла")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        labTestDatePicker = Date()
                        isShowingLabTestDateSheet = true
                    } label: {
                        Text("Обновить дату")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(0.85)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Text("🧪")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Сдача анализов")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let d = labDate {
                            Text(DateFormatter.russianDateTime.string(from: d))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let start = labStart {
                            doctorAppointmentSubtitle(appointmentStart: start)
                        }
                    }
                    Spacer()
                    Button {
                        labTestDatePicker = labDate ?? Date()
                        isShowingLabTestDateSheet = true
                    } label: {
                        Image(systemName: "pencil")
                            .imageScale(.medium)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(labDate != nil && isPast ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var labTestDateSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Дата и время сдачи анализов",
                    selection: $labTestDatePicker,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.locale, Locale(identifier: "ru_RU"))
                Spacer()
            }
            .padding(20)
            .navigationTitle("Сдача анализов")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") {
                        isShowingLabTestDateSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        let date = labTestDatePicker
                        currentProfile?.nextLabTest = date
                        try? modelContext.save()
                        NotificationManager.shared.scheduleLabTestNotification(date: date)
                        isShowingLabTestDateSheet = false
                    }
                }
            }
        }
    }

    private func nextIntakeCard(for group: (time: Date, medications: [Medication])) -> some View {
        let timeString = group.time.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "ru_RU"))
        )
        let allTaken = group.medications.allSatisfy { intakeForToday(medication: $0)?.isTaken == true }

        return VStack(alignment: .leading, spacing: 8) {
            if allTaken {
                Text("✓ Лекарства приняты")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            } else {
                Text("Следующий приём — \(timeString)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(group.medications) { med in
                    let isTaken = intakeForToday(medication: med)?.isTaken == true
                    HStack {
                        Text(med.name)
                            .font(.body)
                        Spacer()
                        Button {
                            toggleTaken(for: med)
                        } label: {
                            Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                                .imageScale(.medium)
                                .foregroundStyle(isTaken ? Color.green : Color.white)
                                .background(
                                    Circle()
                                        .fill(isTaken ? Color.white.opacity(0.0) : Color.white.opacity(0.2))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func medicationsLine(for group: (time: Date, medications: [Medication])) -> some View {
        let timeString = group.time.formatted(
            Date.FormatStyle()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .locale(Locale(identifier: "ru_RU"))
        )
        let names = group.medications.map { $0.name }.joined(separator: ", ")
        let allTaken = group.medications.allSatisfy { intakeForToday(medication: $0)?.isTaken == true }

        let text = allTaken ? "\(timeString) — \(names) ✓" : "\(timeString) — \(names)"

        return Text(text)
            .font(.footnote)
            .foregroundStyle(allTaken ? .secondary : .primary)
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
                Text("Пока нет данных.\nМожно добавить на вкладке \"Показатели\".")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        // Переключение на вкладку «Показатели» должно быть настроено во встраивающем контейнере
    }

    private var quoteSection: some View {
        let quote = dailyQuote

        return VStack(alignment: .leading, spacing: 8) {
            Text("Сегодняшняя мысль")
                .font(.headline)

            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: 3)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 8) {
                    Text("“")
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)

                    Text(quote.text)
                        .font(.body.italic())
                        .foregroundStyle(.primary)

                    Text("— \(quote.author)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
    }

    private var latestBloodPressureValueText: String {
        guard let bp = latestBloodPressure else { return "" }
        return "\(bp.systolic)/\(bp.diastolic)"
    }

    private var latestBloodPressureDateText: String {
        guard let bp = latestBloodPressure else { return "" }
        return formatDateTime(bp.date)
    }

    private var latestWeightValueText: String {
        guard let w = latestWeight else { return "" }
        return String(format: "%.1f кг", w.valueKg)
    }

    private var latestWeightDateText: String {
        guard let w = latestWeight else { return "" }
        return formatDateTime(w.date)
    }

    private func formatDateTime(_ date: Date) -> String {
        DateFormatter.russianDateTime.string(from: date)
    }

    private func daysSince(_ date: Date) -> Int? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let today = Calendar.current.startOfDay(for: Date())
        let components = Calendar.current.dateComponents([.day], from: startOfDay, to: today)
        guard let days = components.day, days >= 0 else { return nil }
        return days + 1
    }

    // MARK: - Приём лекарств: SwiftData

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

