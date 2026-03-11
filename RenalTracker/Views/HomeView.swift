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

    @State private var isShowingSettings = false
    @State private var doctorAppointmentDoctorName: String = ""

    @State private var currentTime = Date()
    @State private var refreshTimer: Timer?

    @Query private var profiles: [UserProfile]
    @Query(sort: \BloodPressure.date, order: .reverse) private var bloodPressureRecords: [BloodPressure]
    @Query(sort: \Weight.date, order: .reverse) private var weightRecords: [Weight]
    @Query(sort: \Medication.name, order: .forward) private var medications: [Medication]
    @Query(sort: \MedicationIntake.date, order: .forward) private var intakes: [MedicationIntake]

    /// Опциональный колбэк для переключения на вкладку «Лекарства»
    var onShowMedications: (() -> Void)?
    /// Опциональный колбэк для переключения на вкладку «Приёмы»
    var onShowDoctorVisits: (() -> Void)?

    init(
        onShowMedications: (() -> Void)? = nil,
        onShowDoctorVisits: (() -> Void)? = nil
    ) {
        self.onShowMedications = onShowMedications
        self.onShowDoctorVisits = onShowDoctorVisits
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
            ("В слабости мы находим силу.", "Лев Толстой"),
            ("Здоровье — это не всё, но без здоровья всё — ничто.", "Артур Шопенгауэр"),
            ("Пока мы откладываем жизнь, она проходит.", "Сенека"),
            ("Не то, что с нами происходит, а наша реакция на это имеет значение.", "Эпиктет"),
            ("Терпение горько, но плод его сладок.", "Жан-Жак Руссо"),
            ("Человек, у которого есть «зачем» жить, может вынести почти любое «как».", "Фридрих Ницше"),
            ("Жизнь — это то, что происходит с тобой, пока ты строишь другие планы.", "Джон Леннон"),
            ("Здоровье дороже богатства.", "Джордж Герберт"),
            ("Сила не в том, чтобы не падать, а в том, чтобы подниматься после каждого падения.", "Конфуций"),
            ("Жизнь — это 10% того, что с тобой происходит, и 90% — как ты на это реагируешь.", "Чарльз Свиндолл"),
            ("У нас есть возможность выбирать отношение к тому, что нам дано.", "Виктор Франкл"),
            ("Действие не всегда приносит счастье; но без действия нет счастья.", "Уинстон Черчилль"),
            ("Счастье — не случайность, не подарок. Оно — результат внутренней работы.", "Далай-лама XIV"),
            ("Время, которое мы имеем, — это время, которое мы выбираем.", "Марк Аврелий"),
            ("Терпение — ключ к радости.", "Абу Хамид аль-Газали"),
            ("Тот, кто знает, зачем жить, вынесет почти любое как.", "Виктор Франкл"),
            ("Здоровье — величайшее из благ.", "Софокл"),
            ("Не бойся медленного прогресса. Бойся стоять на месте.", "Брюс Ли"),
            ("В каждом человеке есть солнце. Только дайте ему светить.", "Сократ"),
            ("Смысл жизни в том, чтобы дать жизни смысл.", "Виктор Франкл"),
            ("Трудности готовят обычных людей к необычной судьбе.", "Клайв Льюис"),
            ("Жизнь измеряется не количеством вдохов, а моментами, что захватывают дух.", "Майя Энджелоу"),
            ("Здоровье так же заразительно, как и болезнь.", "Ромен Роллан"),
            ("Воля — это то, что заставляет тебя побеждать, когда твой разум говорит, что ты побеждён.", "Карлос Кастанеда"),
            ("Страдание перестаёт быть страданием в тот момент, когда обретает смысл.", "Виктор Франкл"),
            ("Человек способен изменить себя, и в этом его главная сила.", "Лев Толстой"),
            ("Не тот велик, кто никогда не падал, а тот велик, кто падал и вставал.", "Конфуций"),
            ("Здоровье — это то единственное, что по-настоящему нужно беречь.", "Антон Чехов"),
            ("Душа исцеляется рядом с детьми.", "Фёдор Достоевский"),
            ("Всё, что не убивает меня, делает меня сильнее.", "Фридрих Ницше"),
            ("Жизнь — это десяти процентов то, что с тобой происходит, и девяноста процентов — как ты на это реагируешь.", "Чарльз Свиндолл"),
            ("Спокойствие приносит здоровье.", "Талмуд"),
            ("Терпение — основа всех добродетелей.", "Иоанн Златоуст"),
            ("Только в темноте видно звёзды.", "Мартин Лютер Кинг"),
            ("Здоровье души так же важно, как здоровье тела.", "Цицерон"),
            ("Надежда — это сон бодрствующего.", "Аристотель"),
            ("Сила в спокойствии.", "Лао-цзы"),
            ("Жизнь прекрасна, если ею правильно пользоваться.", "Сенека"),
            ("Смысл жизни в служении и в том, чтобы приносить пользу другим.", "Лев Толстой"),
            ("Внутренняя свобода — это способность выбирать своё отношение к обстоятельствам.", "Виктор Франкл"),
            ("Здоровье — главное сокровище.", "Публилий Сир"),
            ("Терпение горько, но его плод сладок.", "Жан де Лабрюйер"),
            ("Человек становится тем, о чём он думает.", "Марк Аврелий"),
            ("Счастье приходит к тем, кто помогает другим.", "Альберт Швейцер"),
            ("Дух укрепляется в испытаниях.", "Сенека"),
            ("Жизнь даётся один раз, и хочется прожить её бодро.", "Антон Чехов"),
            ("Вера в себя — первая ступень к успеху.", "Ральф Уолдо Эмерсон"),
            ("Здоровье — это правильное соотношение духа и тела.", "Платон"),
            ("Только тот достоин жизни и свободы, кто каждый день идёт за них на бой.", "Иоганн Вольфганг Гёте"),
            ("Смысл жизни — в любви и в труде.", "Лев Толстой"),
            ("Терпение — искусство надеяться.", "Вольтер"),
            ("Сила не в мышцах, а в несгибаемой воле.", "Махатма Ганди"),
            ("Жизнь — это череда выборов. Выбирай осознанно.", "Виктор Франкл"),
            ("Здоровье духа важнее здоровья тела.", "Эпиктет"),
            ("Надежда — лучший врач из всех, каких я знаю.", "Александр Дюма"),
            ("Воля побеждает привычку.", "Марк Твен"),
            ("Спокойствие — величайшее проявление силы.", "Брюс Ли"),
            ("Жизнь коротка. Искусство вечно. Решение трудно.", "Гиппократ"),
            ("Терпение — мать всех добродетелей.", "Св. Августин"),
            ("Сила — в единстве тела и духа.", "Ювенал"),
            ("Человек живёт, пока живёт его дух.", "Сенека"),
            ("Надежда — якорь души.", "Еврипид"),
            ("Воля к смыслу — главная движущая сила человека.", "Виктор Франкл"),
            ("Жизнь — это не ожидание, что буря пройдёт; это умение танцевать под дождём.", "Вивиан Грин")
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
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Настройки")
                }
            }
        }
        .sheet(isPresented: $isShowingDoctorDateSheet) {
            doctorAppointmentDateSheet
        }
        .sheet(isPresented: $isShowingLabTestDateSheet) {
            labTestDateSheet
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

    // MARK: - Статус события (приём / анализы)

    private enum EventStatus: Equatable {
        case passed
        case today
        case tomorrow
        case upcoming(days: Int)
    }

    private func eventStatus(for date: Date) -> EventStatus {
        let now = currentTime
        let oneHourAfter = date.addingTimeInterval(3600)

        if now > oneHourAfter {
            return .passed
        }

        let cal = Calendar.current
        let diffDays = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: now),
            to: cal.startOfDay(for: date)
        ).day ?? 0

        if diffDays == 0 {
            return .today
        } else if diffDays == 1 {
            return .tomorrow
        } else {
            return .upcoming(days: diffDays)
        }
    }

    @ViewBuilder
    private func eventSubtitleView(_ status: EventStatus) -> some View {
        switch status {
        case .passed:
            EmptyView()
        case .today:
            Text("Сегодня!")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.red)
        case .tomorrow:
            Text("Завтра!")
                .font(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(.yellow)
        case .upcoming(let days):
            Text("Через \(days) \(days == 1 ? "день" : days < 5 ? "дня" : "дней")")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        let status = appointment.map { eventStatus(for: $0) }
        let isPassed = status == .some(.passed)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Следующий приём у врача")
                    .font(.headline)
                Spacer()
                if onShowDoctorVisits != nil {
                    Button("Журнал →") {
                        onShowDoctorVisits?()
                    }
                    .font(.footnote)
                }
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
            } else if isPassed {
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
                        if let s = status {
                            eventSubtitleView(s)
                        }
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
        .background(appointment != nil && isPassed ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
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
        let status = labDate.map { eventStatus(for: $0) }
        let isPassed = status == .some(.passed)

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
            } else if isPassed {
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
                        if let s = status {
                            eventSubtitleView(s)
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
        .background(labDate != nil && isPassed ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground))
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

                    if !quote.author.isEmpty {
                        Text("— \(quote.author)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
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

