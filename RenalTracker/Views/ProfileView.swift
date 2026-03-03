//
//  ProfileView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import PhotosUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                ProfileFormView(profile: profile)
            } else {
                // На случай, если профиля ещё нет (например, не прошли онбординг)
                ProgressView("Загрузка профиля...")
                    .task {
                        if profiles.isEmpty {
                            let newProfile = UserProfile(category: .hemodialysis)
                            modelContext.insert(newProfile)
                            try? modelContext.save()
                        }
                    }
            }
        }
    }
}

// MARK: - Форма профиля

private struct ProfileFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: UserProfile

    @Query(sort: \Medication.name, order: .forward)
    private var medications: [Medication]

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var profileImage: UIImage?

    @State private var isEditing: Bool = false
    @State private var originalSnapshot: ProfileSnapshot?

    // Локальные даты для DatePicker (чтобы не работать с Optional Date напрямую)
    @State private var hemoStartDateLocal: Date = Date()
    @State private var hemoEndDateLocal: Date = Date()
    @State private var pdStartDateLocal: Date = Date()
    @State private var pdEndDateLocal: Date = Date()
    @State private var transplantDateLocal: Date = Date()

    private var displayName: String {
        if let last = profile.lastName, !last.isEmpty {
            return "\(profile.name) \(last)"
        }
        return profile.name
    }

    private var ageText: String {
        if let age = profile.age {
            return "\(age) лет"
        } else {
            return "Не указано"
        }
    }

    private var hemoDurationText: String? {
        guard profile.category == .hemodialysis, let start = profile.hemoStartDate else { return nil }
        let endDate = profile.hemoOngoing ? Date() : (profile.hemoEndDate ?? Date())
        let days = Calendar.current.dateComponents([.day], from: start, to: endDate).day ?? 0
        return "Продолжительность: \(days) дн."
    }

    private var hemoPeriodText: String? {
        guard let start = profile.hemoStartDate else { return nil }
        let startStr = formatDate(start)
        let endStr: String
        if profile.hemoOngoing {
            endStr = "по настоящее время"
        } else if let endDate = profile.hemoEndDate {
            endStr = formatDate(endDate)
        } else {
            endStr = "—"
        }
        return "Период: \(startStr) — \(endStr)"
    }

    private var pdDurationText: String? {
        guard profile.category == .peritonealDialysis, let start = profile.pdStartDate else { return nil }
        let endDate = profile.pdOngoing ? Date() : (profile.pdEndDate ?? Date())
        let days = Calendar.current.dateComponents([.day], from: start, to: endDate).day ?? 0
        return "Продолжительность: \(days) дн."
    }

    private var pdPeriodText: String? {
        guard let start = profile.pdStartDate else { return nil }
        let startStr = formatDate(start)
        let endStr: String
        if profile.pdOngoing {
            endStr = "по настоящее время"
        } else if let endDate = profile.pdEndDate {
            endStr = formatDate(endDate)
        } else {
            endStr = "—"
        }
        return "Период: \(startStr) — \(endStr)"
    }

    private var transplantDurationText: String? {
        guard profile.category == .postTransplant, let date = profile.transplantDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return "Дней со дня операции: \(days)"
    }

    // Форматирование дат в виде "25 января 2026"
    private func formatDate(_ date: Date) -> String {
        DateFormatter.russianDate.string(from: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                personalSection
                statusSection
                medicationsSection
            }
            .navigationTitle("Профиль")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isEditing {
                        Button("Отмена") {
                            cancelEditing()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEditing {
                        Button("Сохранить") {
                            saveProfile()
                        }
                    } else {
                        Button("Редактировать") {
                            startEditing()
                        }
                    }
                }
            }
            .onAppear {
                if let data = profile.photoData, profileImage == nil {
                    profileImage = UIImage(data: data)
                }
                // Синхронизируем локальные даты с моделью
                if let d = profile.hemoStartDate { hemoStartDateLocal = d }
                if let d = profile.hemoEndDate { hemoEndDateLocal = d }
                if let d = profile.pdStartDate { pdStartDateLocal = d }
                if let d = profile.pdEndDate { pdEndDateLocal = d }
                if let d = profile.transplantDate { transplantDateLocal = d }
            }
        }
        .task(id: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                profileImage = image
                profile.photoData = data
            }
        }
    }

    // MARK: - Секции формы

    private var personalSection: some View {
        Section("Личные данные") {
            if isEditing {
                HStack(alignment: .center, spacing: 16) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Имя *", text: $profile.name)
                            .textInputAutocapitalization(.words)
                        TextField(
                            "Фамилия",
                            text: Binding(
                                get: { profile.lastName ?? "" },
                                set: { profile.lastName = $0.isEmpty ? nil : $0 }
                            )
                        )
                        .textInputAutocapitalization(.words)
                        TextField("Возраст", value: $profile.age, format: .number)
                            .keyboardType(.numberPad)
                    }
                }

                TextField(
                    "Телефон пациента",
                    text: Binding(
                        get: { profile.patientPhone ?? "" },
                        set: { profile.patientPhone = $0.isEmpty ? nil : $0 }
                    )
                )
                .keyboardType(.phonePad)
                TextField(
                    "Телефон врача",
                    text: Binding(
                        get: { profile.doctorPhone ?? "" },
                        set: { profile.doctorPhone = $0.isEmpty ? nil : $0 }
                    )
                )
                .keyboardType(.phonePad)
                TextField(
                    "ФИО лечащего врача",
                    text: Binding(
                        get: { profile.doctorName ?? "" },
                        set: { profile.doctorName = $0.isEmpty ? nil : $0 }
                    )
                )
                .textInputAutocapitalization(.words)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName.isEmpty ? "Имя не указано" : displayName)
                            .font(.headline)
                        Text(ageText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Телефон пациента")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.patientPhone?.isEmpty == false ? profile.patientPhone! : "Не указан")
                        .foregroundStyle(profile.patientPhone?.isEmpty == false ? .primary : .secondary)

                    Text("Телефон врача")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.doctorPhone?.isEmpty == false ? profile.doctorPhone! : "Не указан")
                        .foregroundStyle(profile.doctorPhone?.isEmpty == false ? .primary : .secondary)
                    Text("ФИО лечащего врача")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.doctorName?.isEmpty == false ? profile.doctorName! : "Не указано")
                        .foregroundStyle(profile.doctorName?.isEmpty == false ? .primary : .secondary)
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Статус лечения") {
            if isEditing {
                Picker("Статус", selection: $profile.category) {
                    ForEach(UserCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                switch profile.category {
                case .hemodialysis:
                    VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Дата начала", selection: $hemoStartDateLocal, in: ...Date(), displayedComponents: .date)
                        Toggle("По настоящее время", isOn: $profile.hemoOngoing)
                        if !profile.hemoOngoing {
                        DatePicker("Дата окончания", selection: $hemoEndDateLocal, in: ...Date(), displayedComponents: .date)
                        }
                        if let text = hemoDurationText {
                            Text(text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                case .peritonealDialysis:
                    VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Дата начала", selection: $pdStartDateLocal, in: ...Date(), displayedComponents: .date)
                        Toggle("По настоящее время", isOn: $profile.pdOngoing)
                        if !profile.pdOngoing {
                        DatePicker("Дата окончания", selection: $pdEndDateLocal, in: ...Date(), displayedComponents: .date)
                        }
                        if let text = pdDurationText {
                            Text(text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                case .postTransplant:
                    VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Дата операции", selection: $transplantDateLocal, in: ...Date(), displayedComponents: .date)
                        if let text = transplantDurationText {
                            Text(text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(profile.category.rawValue)
                        .font(.headline)

                    switch profile.category {
                    case .hemodialysis:
                        if let period = hemoPeriodText {
                            Text(period)
                        } else {
                            Text("Период не указан")
                                .foregroundStyle(.secondary)
                        }
                        if let text = hemoDurationText {
                            Text(text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                    case .peritonealDialysis:
                        if let period = pdPeriodText {
                            Text(period)
                        } else {
                            Text("Период не указан")
                                .foregroundStyle(.secondary)
                        }
                        if let text = pdDurationText {
                            Text(text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                    case .postTransplant:
                        if let date = profile.transplantDate {
                            Text("Дата операции: \(formatDate(date))")
                        } else {
                            Text("Дата операции не указана")
                                .foregroundStyle(.secondary)
                        }
                        if let text = transplantDurationText {
                            Text(text)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var medicationsSection: some View {
        Section {
            if medications.isEmpty {
                Text("Лекарства не добавлены")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(medications.prefix(3)) { med in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(med.name)
                            .font(.headline)
                        Text(dosageDescription(for: med))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(scheduleDescription(for: med))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            NavigationLink("Все лекарства →") {
                AllMedicationsListView()
            }
            Text("Управление лекарствами — во вкладке \"Лекарства\"")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Мои лекарства")
        }
    }

    // MARK: - Helpers

    private func dosageDescription(for med: Medication) -> String {
        if let amount = med.dosageAmount {
            if med.dosageUnit.isEmpty {
                return String(format: "%.1f", amount)
            } else {
                return String(format: "%.1f %@", amount, med.dosageUnit)
            }
        } else {
            return med.dosageUnit.isEmpty ? "Дозировка не указана" : med.dosageUnit
        }
    }

    private func scheduleDescription(for med: Medication) -> String {
        let time = DateFormatter.russianTime.string(from: med.time)

        let weekdays = med.daysOfWeek.sorted().map { weekdaySymbol(for: $0) }
        let daysText = weekdays.joined(separator: ", ")
        return daysText.isEmpty ? "Время приёма: \(time)" : "\(daysText), в \(time)"
    }

    private func weekdaySymbol(for weekday: Int) -> String {
        switch weekday {
        case 2: return "Пн"
        case 3: return "Вт"
        case 4: return "Ср"
        case 5: return "Чт"
        case 6: return "Пт"
        case 7: return "Сб"
        case 1: return "Вс"
        default: return "?"
        }
    }

    private func saveProfile() {
        // Обновляем даты в зависимости от выбранного статуса
        switch profile.category {
        case .hemodialysis:
            profile.hemoStartDate = hemoStartDateLocal
            profile.hemoEndDate = profile.hemoOngoing ? nil : hemoEndDateLocal
            // Сбрасываем другие статусы
            profile.pdStartDate = nil
            profile.pdEndDate = nil
            profile.pdOngoing = false
            profile.transplantDate = nil

        case .peritonealDialysis:
            profile.pdStartDate = pdStartDateLocal
            profile.pdEndDate = profile.pdOngoing ? nil : pdEndDateLocal
            // Сбрасываем другие статусы
            profile.hemoStartDate = nil
            profile.hemoEndDate = nil
            profile.hemoOngoing = false
            profile.transplantDate = nil

        case .postTransplant:
            profile.transplantDate = transplantDateLocal
            // Сбрасываем другие статусы
            profile.hemoStartDate = nil
            profile.hemoEndDate = nil
            profile.hemoOngoing = false
            profile.pdStartDate = nil
            profile.pdEndDate = nil
            profile.pdOngoing = false
        }

        // Сохраняем изменения профиля
        try? modelContext.save()
        isEditing = false
        originalSnapshot = nil
    }

    private func startEditing() {
        originalSnapshot = ProfileSnapshot(from: profile)
        // локальные даты уже синхронизированы в onAppear / можно обновить ещё раз
        if let d = profile.hemoStartDate { hemoStartDateLocal = d }
        if let d = profile.hemoEndDate { hemoEndDateLocal = d }
        if let d = profile.pdStartDate { pdStartDateLocal = d }
        if let d = profile.pdEndDate { pdEndDateLocal = d }
        if let d = profile.transplantDate { transplantDateLocal = d }
        isEditing = true
    }

    private func cancelEditing() {
        if let snapshot = originalSnapshot {
            snapshot.apply(to: profile)
        }
        // Обновляем локальные даты из восстановленного профиля
        if let d = profile.hemoStartDate { hemoStartDateLocal = d }
        if let d = profile.hemoEndDate { hemoEndDateLocal = d }
        if let d = profile.pdStartDate { pdStartDateLocal = d }
        if let d = profile.pdEndDate { pdEndDateLocal = d }
        if let d = profile.transplantDate { transplantDateLocal = d }
        isEditing = false
        originalSnapshot = nil
    }
}

// MARK: - Полный список лекарств

private struct AllMedicationsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Medication.name, order: .forward) private var medications: [Medication]

    var body: some View {
        List {
            ForEach(medications) { med in
                VStack(alignment: .leading, spacing: 4) {
                    Text(med.name)
                        .font(.headline)
                    Text(dosageDescription(for: med))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(scheduleDescription(for: med))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Все лекарства")
    }

    private func dosageDescription(for med: Medication) -> String {
        if let amount = med.dosageAmount {
            if med.dosageUnit.isEmpty {
                return String(format: "%.1f", amount)
            } else {
                return String(format: "%.1f %@", amount, med.dosageUnit)
            }
        } else {
            return med.dosageUnit.isEmpty ? "Дозировка не указана" : med.dosageUnit
        }
    }

    private func scheduleDescription(for med: Medication) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: med.time)

        let weekdays = med.daysOfWeek.sorted().map { weekdaySymbol(for: $0) }
        let daysText = weekdays.joined(separator: ", ")
        return daysText.isEmpty ? "Время приёма: \(time)" : "\(daysText), в \(time)"
    }

    private func weekdaySymbol(for weekday: Int) -> String {
        switch weekday {
        case 2: return "Пн"
        case 3: return "Вт"
        case 4: return "Ср"
        case 5: return "Чт"
        case 6: return "Пт"
        case 7: return "Сб"
        case 1: return "Вс"
        default: return "?"
        }
    }
}

// MARK: - Редактирование лекарства

private struct EditMedicationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var medication: Medication

    @State private var dosageAmountText: String
    @State private var selectedDays: Set<Int>

    private struct WeekdayOption: Identifiable {
        let id: Int   // Calendar weekday (1...7)
        let shortTitle: String
    }

    private let weekdayOptions: [WeekdayOption] = [
        .init(id: 2, shortTitle: "Пн"),
        .init(id: 3, shortTitle: "Вт"),
        .init(id: 4, shortTitle: "Ср"),
        .init(id: 5, shortTitle: "Чт"),
        .init(id: 6, shortTitle: "Пт"),
        .init(id: 7, shortTitle: "Сб"),
        .init(id: 1, shortTitle: "Вс")
    ]

    init(medication: Medication) {
        self.medication = medication
        if let amount = medication.dosageAmount {
            _dosageAmountText = State(initialValue: String(amount))
        } else {
            _dosageAmountText = State(initialValue: "")
        }
        _selectedDays = State(initialValue: Set(medication.daysOfWeek))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Лекарство") {
                    TextField("Наименование", text: $medication.name)
                    HStack {
                        TextField("Количество", text: $dosageAmountText)
                            .keyboardType(.decimalPad)
                        TextField("Ед. изм. (например, мг)", text: $medication.dosageUnit)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section("Дни приёма") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            ForEach(weekdayOptions) { option in
                                let isSelected = selectedDays.contains(option.id)
                                Button {
                                    toggleDay(option.id)
                                } label: {
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
                        if selectedDays.isEmpty {
                            Text("Выберите хотя бы один день.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Время приёма") {
                    DatePicker("Время", selection: $medication.time, displayedComponents: .hourAndMinute)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
            .navigationTitle("Редактирование")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        save()
                    }
                }
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

    private func save() {
        let normalizedAmount = dosageAmountText.replacingOccurrences(of: ",", with: ".")
        medication.dosageAmount = Double(normalizedAmount)
        medication.daysOfWeek = Array(selectedDays)

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Snapshot для режима редактирования

private struct ProfileSnapshot {
    var name: String
    var lastName: String?
    var age: Int?
    var patientPhone: String?
    var doctorPhone: String?
    var doctorName: String?
    var category: UserCategory
    var hemoStartDate: Date?
    var hemoEndDate: Date?
    var hemoOngoing: Bool
    var pdStartDate: Date?
    var pdEndDate: Date?
    var pdOngoing: Bool
    var transplantDate: Date?
    var photoData: Data?

    init(from profile: UserProfile) {
        self.name = profile.name
        self.lastName = profile.lastName
        self.age = profile.age
        self.patientPhone = profile.patientPhone
        self.doctorPhone = profile.doctorPhone
        self.doctorName = profile.doctorName
        self.category = profile.category
        self.hemoStartDate = profile.hemoStartDate
        self.hemoEndDate = profile.hemoEndDate
        self.hemoOngoing = profile.hemoOngoing
        self.pdStartDate = profile.pdStartDate
        self.pdEndDate = profile.pdEndDate
        self.pdOngoing = profile.pdOngoing
        self.transplantDate = profile.transplantDate
        self.photoData = profile.photoData
    }

    func apply(to profile: UserProfile) {
        profile.name = name
        profile.lastName = lastName
        profile.age = age
        profile.patientPhone = patientPhone
        profile.doctorPhone = doctorPhone
        profile.doctorName = doctorName
        profile.category = category
        profile.hemoStartDate = hemoStartDate
        profile.hemoEndDate = hemoEndDate
        profile.hemoOngoing = hemoOngoing
        profile.pdStartDate = pdStartDate
        profile.pdEndDate = pdEndDate
        profile.pdOngoing = pdOngoing
        profile.transplantDate = transplantDate
        profile.photoData = photoData
    }
}


