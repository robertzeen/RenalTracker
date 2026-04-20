//
//  OnboardingView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import PhotosUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var currentStep: Int = 0 // 0-2 слайды, 3 личные данные, 4 статус

    // Шаг 4: личные данные
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var birthDate: Date = Date()
    @State private var birthDay: Int = Calendar.current.component(.day, from: Date())
    @State private var birthMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var birthYear: Int = Calendar.current.component(.year, from: Date())
    @State private var patientPhone: String = ""
    @State private var doctorPhone: String = ""
    @State private var doctorName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var avatarImageData: Data?

    // Шаг 5: статус
    @State private var selectedCategory: UserCategory = .hemodialysis
    @State private var hemoStartDate: Date = Date()
    @State private var hemoEndDate: Date = Date()
    @State private var hemoOngoing: Bool = true
    @State private var pdStartDate: Date = Date()
    @State private var pdEndDate: Date = Date()
    @State private var pdOngoing: Bool = true
    @State private var transplantDate: Date = Date()

    var onComplete: () -> Void

    private let totalSteps = 5

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer(minLength: 0)

                VStack(spacing: 24) {
                    switch currentStep {
                    case 0: introSlide(imageName: "onboarding_slide1",
                                       title: "Контроль здоровья",
                                       text: "Отслеживайте давление, вес и анализы крови в одном месте.\nНаблюдайте за динамикой на графиках.")
                    case 1: introSlide(imageName: "onboarding_slide2",
                                       title: "Лекарства под контролем",
                                       text: "Составьте расписание приёма лекарств и получайте\nнапоминания вовремя. Не пропустите ни одной дозы.")
                    case 2: introSlide(imageName: "onboarding_slide3",
                                       title: "Экспорт отчётов",
                                       text: "Формируйте PDF отчёты с графиками для врача.\nВся история в одном документе.")
                    case 3: personalStep
                    case 4: statusStep
                    default: EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .animation(.easeInOut, value: currentStep)

                Spacer(minLength: 0)

                VStack(spacing: 16) {
                    stepIndicators

                    Button(action: nextTapped) {
                        Text(primaryButtonTitle)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isPrimaryButtonDisabled ? Color.gray.opacity(0.3) : Color.accentColor)
                            .foregroundColor(isPrimaryButtonDisabled ? .gray : .white)
                            .cornerRadius(12)
                    }
                    .disabled(isPrimaryButtonDisabled)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Слайды о приложении (шаги 0-2)

    @ViewBuilder
    private func introSlide(imageName: String, title: String, text: String) -> some View {
        VStack(spacing: 24) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 250)
                .padding(.top, 40)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Личные данные (шаг 3)

    private var personalStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Расскажите о себе")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 16) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        if let data = avatarImageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(radius: 4)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .task(id: selectedPhotoItem) { @MainActor in
                    guard let item = selectedPhotoItem else { return }
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        avatarImageData = data
                    }
                }

                TextField("Имя *", text: $firstName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                TextField("Фамилия", text: $lastName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Дата рождения (опционально)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Picker("День", selection: $birthDay) {
                            ForEach(availableBirthDays, id: \.self) { day in
                                Text("\(day)")
                                    .tag(day)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Месяц", selection: $birthMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthSymbol(for: month))
                                    .tag(month)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Год", selection: $birthYear) {
                            ForEach(birthYearRange, id: \.self) { year in
                                Text(String(format: "%d", year))
                                    .tag(year)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: birthDay) { _, _ in
                        updateBirthDateFromComponents()
                    }
                    .onChange(of: birthMonth) { _, _ in
                        updateBirthDateFromComponents()
                    }
                    .onChange(of: birthYear) { _, _ in
                        updateBirthDateFromComponents()
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Телефон пациента (опционально)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Телефон пациента", text: $patientPhone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Телефон врача (опционально)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Телефон врача", text: $doctorPhone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("ФИО лечащего врача (опционально)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("ФИО лечащего врача", text: $doctorName)
                        .textInputAutocapitalization(.words)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    // MARK: - Статус лечения (шаг 4)

    private var statusStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ваш статус")
                .font(.title)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                statusCard(
                    icon: "💉",
                    title: "Гемодиализ",
                    category: .hemodialysis
                )
                statusCard(
                    icon: "💧",
                    title: "Перитонеальный диализ",
                    category: .peritonealDialysis
                )
                statusCard(
                    icon: "🌱",
                    title: "После трансплантации почки",
                    category: .postTransplant
                )
            }

            VStack(alignment: .leading, spacing: 12) {
                switch selectedCategory {
                case .hemodialysis:
                    dialysisStatusView(
                        startDate: $hemoStartDate,
                        endDate: $hemoEndDate,
                        ongoing: $hemoOngoing,
                        titleStart: "Дата начала",
                        titleEnd: "Дата окончания"
                    )
                    if let days = durationDays(start: hemoStartDate, end: hemoOngoing ? Date() : hemoEndDate) {
                        Text("Продолжительность: \(days) дней")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .peritonealDialysis:
                    dialysisStatusView(
                        startDate: $pdStartDate,
                        endDate: $pdEndDate,
                        ongoing: $pdOngoing,
                        titleStart: "Дата начала",
                        titleEnd: "Дата окончания"
                    )
                    if let days = durationDays(start: pdStartDate, end: pdOngoing ? Date() : pdEndDate) {
                        Text("Продолжительность: \(days) дней")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                case .postTransplant:
                    VStack(alignment: .leading, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Дата операции")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DatePicker("Дата операции", selection: $transplantDate, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ru_RU"))
                        }

                        if let days = durationDays(start: transplantDate, end: Date()) {
                            Text("Дней со дня операции: \(days)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func statusCard(icon: String, title: String, category: UserCategory) -> some View {
        let isSelected = selectedCategory == category

        return Button {
            withAnimation(.easeInOut) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.title2)

                Text(title)
                    .font(.body)
                    .fontWeight(.medium)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dialysisStatusView(
        startDate: Binding<Date>,
        endDate: Binding<Date>,
        ongoing: Binding<Bool>,
        titleStart: String,
        titleEnd: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(titleStart)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DatePicker(titleStart, selection: startDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .environment(\.locale, Locale(identifier: "ru_RU"))
            }

            Toggle("По настоящее время", isOn: ongoing)

            if !ongoing.wrappedValue {
                VStack(alignment: .leading, spacing: 4) {
                    Text(titleEnd)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DatePicker(titleEnd, selection: endDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
        }
    }

    // MARK: - Навигация и логика

    private var primaryButtonTitle: String {
        switch currentStep {
        case 0, 1: return "Далее"
        case 2: return "Начать"
        case 3: return "Далее"
        case 4: return "Завершить"
        default: return "Далее"
        }
    }

    private var isPrimaryButtonDisabled: Bool {
        if currentStep == 3 {
            return firstName.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return false
    }

    private func nextTapped() {
        if currentStep < totalSteps - 1 {
            withAnimation(.easeInOut) {
                currentStep += 1
            }
        } else {
            finishOnboarding()
        }
    }

    private var stepIndicators: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func durationDays(start: Date, end: Date) -> Int? {
        let components = Calendar.current.dateComponents([.day], from: start, to: end)
        guard let days = components.day, days >= 0 else { return nil }
        return days
    }

    // MARK: - Дата рождения: вспомогательные функции

    private var birthYearRange: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        let startYear = max(currentYear - 100, 1900)
        return Array(stride(from: currentYear, through: startYear, by: -1))
    }

    private var availableBirthDays: [Int] {
        var components = DateComponents()
        components.year = birthYear
        components.month = birthMonth
        components.day = 1
        let calendar = Calendar.current
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return Array(1...31)
        }
        return Array(range)
    }

    private func monthSymbol(for month: Int) -> String {
        DateFormatter.russianMonthSymbols[month - 1]
    }

    private func updateBirthDateFromComponents() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = birthYear
        components.month = birthMonth
        let maxDay = availableBirthDays.max() ?? 31
        components.day = min(birthDay, maxDay)

        if let date = calendar.date(from: components), date <= Date() {
            birthDate = date
            birthDay = calendar.component(.day, from: date)
            birthMonth = calendar.component(.month, from: date)
            birthYear = calendar.component(.year, from: date)
        }
    }

    private func finishOnboarding() {
        let profile = UserProfile(category: selectedCategory, name: firstName, birthDate: birthDate, hasCompletedOnboarding: true)

        profile.lastName = lastName.isEmpty ? nil : lastName

        // возраст по дате рождения (если разумный диапазон)
        let ageYears = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        if ageYears > 0 && ageYears < 130 {
            profile.age = ageYears
        }

        profile.patientPhone = patientPhone.isEmpty ? nil : patientPhone
        profile.doctorPhone = doctorPhone.isEmpty ? nil : doctorPhone
        profile.doctorName = doctorName.isEmpty ? nil : doctorName

        if let avatarData = avatarImageData {
            profile.photoData = avatarData
        }

        switch selectedCategory {
        case .hemodialysis:
            profile.hemoStartDate = hemoStartDate
            profile.hemoEndDate = hemoOngoing ? nil : hemoEndDate
            profile.hemoOngoing = hemoOngoing
            profile.pdStartDate = nil
            profile.pdEndDate = nil
            profile.pdOngoing = false
            profile.transplantDate = nil

        case .peritonealDialysis:
            profile.pdStartDate = pdStartDate
            profile.pdEndDate = pdOngoing ? nil : pdEndDate
            profile.pdOngoing = pdOngoing
            profile.hemoStartDate = nil
            profile.hemoEndDate = nil
            profile.hemoOngoing = false
            profile.transplantDate = nil

        case .postTransplant:
            profile.transplantDate = transplantDate
            profile.hemoStartDate = nil
            profile.hemoEndDate = nil
            profile.hemoOngoing = false
            profile.pdStartDate = nil
            profile.pdEndDate = nil
            profile.pdOngoing = false
        }

        modelContext.insert(profile)
        try? modelContext.save()

        onComplete()
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .modelContainer(for: UserProfile.self, inMemory: true)
}

