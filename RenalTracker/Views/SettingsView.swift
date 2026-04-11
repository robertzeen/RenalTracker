//
//  SettingsView.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    var profile: UserProfile
    var onDismiss: () -> Void

    // MARK: - Личные данные
    @State private var firstName: String
    @State private var lastName: String

    // MARK: - Статус лечения
    @State private var selectedCategory: UserCategory
    @State private var showChangeAlert = false
    @State private var pendingCategory: UserCategory?

    @State private var hemoStartDate: Date
    @State private var hemoEndDate: Date
    @State private var hemoOngoing: Bool
    @State private var pdStartDate: Date
    @State private var pdEndDate: Date
    @State private var pdOngoing: Bool
    @State private var transplantDate: Date

    // MARK: - Уведомления
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("criticalNotificationsEnabled") var criticalNotificationsEnabled = false
    @AppStorage("bpReminderEnabled") var bpReminderEnabled = false
    @AppStorage("weightReminderEnabled") var weightReminderEnabled = false

    @State private var bpMorningTime: Date = UserDefaults.standard.object(forKey: "bpMorningReminderTime") as? Date
        ?? Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? Date()
    @State private var bpEveningTime: Date = UserDefaults.standard.object(forKey: "bpEveningReminderTime") as? Date
        ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    @State private var weightReminderTime: Date = UserDefaults.standard.object(forKey: "weightReminderTime") as? Date
        ?? Calendar.current.date(from: DateComponents(hour: 7, minute: 30)) ?? Date()

    @State private var showBPMorningPicker = false
    @State private var showBPEveningPicker = false
    @State private var showWeightPicker = false

    // MARK: - Кастомные метрики
    @Query(sort: \CustomMetric.sortOrder) private var metrics: [CustomMetric]
    @State private var isShowingAddCustomMetric = false

    init(profile: UserProfile, onDismiss: @escaping () -> Void) {
        self.profile = profile
        self.onDismiss = onDismiss
        _firstName        = State(initialValue: profile.name)
        _lastName         = State(initialValue: profile.lastName ?? "")
        _selectedCategory = State(initialValue: profile.category)
        _hemoStartDate    = State(initialValue: profile.hemoStartDate ?? Date())
        _hemoEndDate      = State(initialValue: profile.hemoEndDate ?? Date())
        _hemoOngoing      = State(initialValue: profile.hemoOngoing)
        _pdStartDate      = State(initialValue: profile.pdStartDate ?? Date())
        _pdEndDate        = State(initialValue: profile.pdEndDate ?? Date())
        _pdOngoing        = State(initialValue: profile.pdOngoing)
        _transplantDate   = State(initialValue: profile.transplantDate ?? Date())
    }

    // MARK: - Вспомогательные

    private func categoryIcon(_ cat: UserCategory) -> String {
        switch cat {
        case .hemodialysis:       return "💉"
        case .peritonealDialysis: return "💧"
        case .postTransplant:     return "🌱"
        }
    }

    private func categoryTitle(_ cat: UserCategory) -> String {
        switch cat {
        case .hemodialysis:       return "Гемодиализ"
        case .peritonealDialysis: return "Перитонеальный диализ"
        case .postTransplant:     return "После трансплантации"
        }
    }

    private func categorySubtitle(_ cat: UserCategory) -> String {
        switch cat {
        case .hemodialysis:
            let end = hemoOngoing ? Date() : hemoEndDate
            if let days = durationDays(start: hemoStartDate, end: end) {
                return "День \(days) · c \(DateFormatter.russianDate.string(from: hemoStartDate))"
            }
            return "С \(DateFormatter.russianDate.string(from: hemoStartDate))"
        case .peritonealDialysis:
            let end = pdOngoing ? Date() : pdEndDate
            if let days = durationDays(start: pdStartDate, end: end) {
                return "День \(days) · c \(DateFormatter.russianDate.string(from: pdStartDate))"
            }
            return "С \(DateFormatter.russianDate.string(from: pdStartDate))"
        case .postTransplant:
            if let days = durationDays(start: transplantDate, end: Date()) {
                return "День \(days) после операции"
            }
            return DateFormatter.russianDate.string(from: transplantDate)
        }
    }

    private func durationDays(start: Date, end: Date) -> Int? {
        let components = Calendar.current.dateComponents([.day], from: start, to: end)
        guard let days = components.day, days >= 0 else { return nil }
        return days
    }

    private func resetDatesForCategory(_ category: UserCategory) {
        switch category {
        case .hemodialysis:
            hemoStartDate = Date(); hemoEndDate = Date(); hemoOngoing = true
        case .peritonealDialysis:
            pdStartDate = Date(); pdEndDate = Date(); pdOngoing = true
        case .postTransplant:
            transplantDate = Date()
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    personalSection
                    treatmentSection
                    notificationsCard
                    customMetricsSection
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") { saveAndDismiss() }
                        .fontWeight(.medium)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil)
                    }
                }
            }
            .onAppear {
                initializePredefinedMetrics()
            }
            .sheet(isPresented: $isShowingAddCustomMetric) {
                AddCustomMetricView()
                    .presentationDetents([.medium, .large])
            }
            .alert("Изменить статус лечения?", isPresented: $showChangeAlert) {
                Button("Отмена", role: .cancel) { pendingCategory = nil }
                Button("Изменить") {
                    if let newCategory = pendingCategory {
                        selectedCategory = newCategory
                        resetDatesForCategory(newCategory)
                    }
                    pendingCategory = nil
                }
            } message: {
                Text("Отсчёт дней на главном экране будет пересчитан с новой даты.")
            }
        }
    }

    // MARK: - Личные данные

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ЛИЧНЫЕ ДАННЫЕ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ИМЯ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Имя", text: $firstName)
                            .font(.system(size: 15, weight: .medium))
                    }
                    Spacer()
                }
                .padding(14)

                Divider().padding(.leading, 14)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ФАМИЛИЯ")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("Фамилия", text: $lastName)
                            .font(.system(size: 15, weight: .medium))
                    }
                    Spacer()
                }
                .padding(14)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))
        }
    }

    // MARK: - Статус лечения

    private var treatmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("СТАТУС ЛЕЧЕНИЯ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            ForEach(UserCategory.allCases, id: \.self) { category in
                let isSelected = selectedCategory == category
                HStack(spacing: 12) {
                    Text(categoryIcon(category))
                        .font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(categoryTitle(category))
                            .font(.system(size: 15, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        if isSelected {
                            Text(categorySubtitle(category))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.blue : Color(.separator),
                            lineWidth: isSelected ? 2 : 0.5))
                .onTapGesture {
                    if selectedCategory != category {
                        pendingCategory = category
                        showChangeAlert = true
                    }
                }
            }

            // Поля дат для активного статуса
            treatmentDateCard
        }
    }

    @ViewBuilder
    private var treatmentDateCard: some View {
        VStack(spacing: 0) {
            switch selectedCategory {
            case .hemodialysis:
                dateCardRow(title: "ДАТА НАЧАЛА") {
                    DatePicker("", selection: $hemoStartDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
                Divider().padding(.leading, 14)
                toggleRow(title: "По настоящее время", isOn: $hemoOngoing)
                if !hemoOngoing {
                    Divider().padding(.leading, 14)
                    dateCardRow(title: "ДАТА ОКОНЧАНИЯ") {
                        DatePicker("", selection: $hemoEndDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }
                }

            case .peritonealDialysis:
                dateCardRow(title: "ДАТА НАЧАЛА") {
                    DatePicker("", selection: $pdStartDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
                Divider().padding(.leading, 14)
                toggleRow(title: "По настоящее время", isOn: $pdOngoing)
                if !pdOngoing {
                    Divider().padding(.leading, 14)
                    dateCardRow(title: "ДАТА ОКОНЧАНИЯ") {
                        DatePicker("", selection: $pdEndDate, in: ...Date(), displayedComponents: .date)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                    }
                }

            case .postTransplant:
                dateCardRow(title: "ДАТА ОПЕРАЦИИ") {
                    DatePicker("", selection: $transplantDate, in: ...Date(), displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.separator), lineWidth: 0.5))
    }

    private func dateCardRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                content()
            }
            Spacer()
        }
        .padding(14)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(14)
    }

    // MARK: - Уведомления

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("УВЕДОМЛЕНИЯ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Уведомления о лекарствах
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Уведомления о лекарствах")
                            .font(.system(size: 15, weight: .medium))
                        Text("Напоминания по расписанию")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                NotificationManager.shared.updateNotifications()
                            } else {
                                NotificationManager.shared.disableMedicationNotifications()
                                criticalNotificationsEnabled = false
                            }
                        }
                }
                .padding(14)

                Divider().padding(.leading, 14)

                // В режиме «Не беспокоить»
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("В режиме «Не беспокоить»")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(notificationsEnabled ? .primary : .secondary)
                        Text("Уведомления о лекарствах всё равно придут")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $criticalNotificationsEnabled)
                        .labelsHidden()
                        .disabled(!notificationsEnabled)
                        .onChange(of: criticalNotificationsEnabled) { _, _ in
                            if notificationsEnabled {
                                NotificationManager.shared.updateNotifications()
                            }
                        }
                }
                .padding(14)

                Divider().padding(.leading, 14)

                // Напоминание о давлении
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Напоминание об измерении давления")
                            .font(.system(size: 15, weight: .medium))
                        Text("Утреннее и вечернее")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $bpReminderEnabled)
                        .labelsHidden()
                        .onChange(of: bpReminderEnabled) { _, enabled in
                            if !enabled {
                                showBPMorningPicker = false
                                showBPEveningPicker = false
                            }
                            NotificationManager.shared.scheduleMeasurementReminders()
                        }
                }
                .padding(14)

                if bpReminderEnabled {
                    Divider().padding(.leading, 14)

                    // Утреннее время
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("УТРЕННЕЕ ИЗМЕРЕНИЕ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(DateFormatter.russianTime.string(from: bpMorningTime))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: showBPMorningPicker ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                    .onTapGesture { showBPMorningPicker.toggle() }

                    if showBPMorningPicker {
                        Divider()
                        DatePicker("", selection: $bpMorningTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .frame(maxWidth: .infinity)
                            .onChange(of: bpMorningTime) { _, _ in
                                UserDefaults.standard.set(bpMorningTime, forKey: "bpMorningReminderTime")
                                NotificationManager.shared.scheduleMeasurementReminders()
                            }
                    }

                    Divider().padding(.leading, 14)

                    // Вечернее время
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ВЕЧЕРНЕЕ ИЗМЕРЕНИЕ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(DateFormatter.russianTime.string(from: bpEveningTime))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: showBPEveningPicker ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                    .onTapGesture { showBPEveningPicker.toggle() }

                    if showBPEveningPicker {
                        Divider()
                        DatePicker("", selection: $bpEveningTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .frame(maxWidth: .infinity)
                            .onChange(of: bpEveningTime) { _, _ in
                                UserDefaults.standard.set(bpEveningTime, forKey: "bpEveningReminderTime")
                                NotificationManager.shared.scheduleMeasurementReminders()
                            }
                    }
                }

                Divider().padding(.leading, 14)

                // Напоминание о взвешивании
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Напоминание о взвешивании")
                            .font(.system(size: 15, weight: .medium))
                        Text("Ежедневное утреннее")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $weightReminderEnabled)
                        .labelsHidden()
                        .onChange(of: weightReminderEnabled) { _, enabled in
                            if !enabled { showWeightPicker = false }
                            NotificationManager.shared.scheduleMeasurementReminders()
                        }
                }
                .padding(14)

                if weightReminderEnabled {
                    Divider().padding(.leading, 14)

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ВРЕМЯ ВЗВЕШИВАНИЯ")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text(DateFormatter.russianTime.string(from: weightReminderTime))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        Spacer()
                        Image(systemName: showWeightPicker ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .contentShape(Rectangle())
                    .onTapGesture { showWeightPicker.toggle() }

                    if showWeightPicker {
                        Divider()
                        DatePicker("", selection: $weightReminderTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))
                            .frame(maxWidth: .infinity)
                            .onChange(of: weightReminderTime) { _, _ in
                                UserDefaults.standard.set(weightReminderTime, forKey: "weightReminderTime")
                                NotificationManager.shared.scheduleMeasurementReminders()
                            }
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))
        }
    }

    // MARK: - Кастомные метрики

    private var predefinedMetrics: [CustomMetric] {
        metrics.filter { !$0.isCustom }
    }

    private var customMetrics: [CustomMetric] {
        metrics.filter { $0.isCustom }
    }

    private func initializePredefinedMetrics() {
        guard metrics.isEmpty else { return }
        for definition in CustomMetricCatalog.predefined {
            let metric = CustomMetric(
                name: definition.name,
                unit: definition.unit,
                icon: definition.icon,
                isActive: false,
                isCustom: false,
                sortOrder: definition.sortOrder
            )
            modelContext.insert(metric)
        }
        try? modelContext.save()
    }

    private func deleteCustomMetric(_ metric: CustomMetric) {
        modelContext.delete(metric)
        try? modelContext.save()
    }

    private var customMetricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ДОПОЛНИТЕЛЬНЫЕ ПОКАЗАТЕЛИ")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            // Предустановленные метрики
            VStack(spacing: 0) {
                ForEach(Array(predefinedMetrics.enumerated()), id: \.element.id) { index, metric in
                    if index > 0 { Divider().padding(.leading, 56) }
                    HStack {
                        Image(systemName: metric.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(.blue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.name)
                                .font(.system(size: 15, weight: .medium))
                            Text(metric.unit)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { metric.isActive },
                            set: { newValue in
                                metric.isActive = newValue
                                try? modelContext.save()
                            }
                        ))
                        .labelsHidden()
                    }
                    .padding(14)
                }

                if !predefinedMetrics.isEmpty {
                    Divider().padding(.leading, 14)
                }

                // Кнопка добавления своей метрики
                Button {
                    isShowingAddCustomMetric = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Добавить свою метрику")
                            .font(.system(size: 15))
                            .foregroundStyle(.blue)
                    }
                    .padding(14)
                }
                .buttonStyle(.plain)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5))

            // Кастомные метрики пользователя
            if !customMetrics.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(customMetrics.enumerated()), id: \.element.id) { index, metric in
                        if index > 0 { Divider().padding(.leading, 56) }
                        HStack {
                            Image(systemName: metric.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(metric.name)
                                    .font(.system(size: 15, weight: .medium))
                                Text(metric.unit)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { metric.isActive },
                                set: { newValue in
                                    metric.isActive = newValue
                                    try? modelContext.save()
                                }
                            ))
                            .labelsHidden()

                            Button {
                                deleteCustomMetric(metric)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                        }
                        .padding(14)
                    }
                }
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 0.5))
            }
        }
    }

    // MARK: - Сохранение

    private func saveAndDismiss() {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast  = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.name     = trimmedFirst.isEmpty ? "друг" : trimmedFirst
        profile.lastName = trimmedLast.isEmpty ? nil : trimmedLast
        profile.category = selectedCategory

        switch selectedCategory {
        case .hemodialysis:
            profile.hemoStartDate = hemoStartDate
            profile.hemoEndDate   = hemoOngoing ? nil : hemoEndDate
            profile.hemoOngoing   = hemoOngoing
            profile.pdStartDate   = nil; profile.pdEndDate = nil; profile.pdOngoing = false
            profile.transplantDate = nil
        case .peritonealDialysis:
            profile.pdStartDate   = pdStartDate
            profile.pdEndDate     = pdOngoing ? nil : pdEndDate
            profile.pdOngoing     = pdOngoing
            profile.hemoStartDate = nil; profile.hemoEndDate = nil; profile.hemoOngoing = false
            profile.transplantDate = nil
        case .postTransplant:
            profile.transplantDate = transplantDate
            profile.hemoStartDate  = nil; profile.hemoEndDate = nil; profile.hemoOngoing = false
            profile.pdStartDate    = nil; profile.pdEndDate = nil; profile.pdOngoing = false
        }

        try? modelContext.save()
        onDismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: UserProfile.self, configurations: config)
    let profile = UserProfile(category: .hemodialysis, name: "Иван", hasCompletedOnboarding: true)
    container.mainContext.insert(profile)
    return SettingsView(profile: profile, onDismiss: {})
        .modelContainer(container)
}
