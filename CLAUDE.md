# RenalTracker — Project Context

## Описание проекта
iOS приложение для пациентов на гемодиализе, перитонеальном диализе
и после трансплантации почки. Помогает отслеживать здоровье,
лекарства и визиты к врачу.

## Технический стек
- SwiftUI + SwiftData
- iOS 17.2, deployment target iPhone
- Xcode на macOS
- **Никогда не запускать xcodebuild команды**

---

## Текущий статус разработки

### Завершено
- Онбординг (5 шагов)
- Главный экран (дашборд с метриками, лекарствами, событиями, цитатой)
- Метрики: АД, пульс, вес — графики, история, PDF экспорт
- Анализы: каталог (16 тестов) + кастомные, графики, PDF экспорт
- Лекарства: расписание, отметка приёма, свайп-действия, PDF экспорт
- Визиты к врачу: история, детали, добавление/редактирование
- Настройки: профиль, статус лечения, уведомления, управление кастомными метриками
- Уведомления: лекарства, АД, вес, визиты, анализы
- SwiftData миграция: VersionedSchema V1→V2 (AppMigrationPlan)
- Модели CustomMetric и CustomMetricEntry (V2)
- Каталог кастомных метрик (CustomMetricCatalog, 7 метрик)
- **CustomMetrics UI** — полностью реализован:
  - SettingsView: раздел "ДОПОЛНИТЕЛЬНЫЕ ПОКАЗАТЕЛИ" — включение/выключение из каталога, добавление своих
  - IndicatorsView: карточки активных метрик с графиком (LineMark+catmullRom), синхронизированный ChartPeriod picker
  - CustomMetricListView: история записей по месяцам, свайп-удаление, PDF экспорт со статистикой
  - AddCustomMetricEntrySheet: ввод значения + дата/время
  - AddCustomMetricView: создание кастомной метрики (имя, единица, иконка из сетки SF Symbols)
- Переименование вкладки "Показатели" → "Метрики" во всех 6 файлах

### В работе / Незавершено
- **WellBeing** — модель есть (`weakness`, `headache`, `swelling`), UI отсутствует

---

## Структура проекта

### Views

| Файл | Назначение |
|------|-----------|
| `ContentView.swift` | Корневой view: онбординг или MainTabView (по `hasCompletedOnboarding`) |
| `MainTabView.swift` | TabView с 5 вкладками, `selectedTab: Int` |
| `OnboardingView.swift` | 5-шаговый онбординг: 3 intro-слайда, личные данные, статус лечения |
| `HomeView.swift` | Дашборд: приветствие, последние метрики, лекарства на сегодня, события, цитата; Timer каждые 60 сек |
| `HomeGreetingView.swift` | Приветствие + имя + статус ("День N после трансплантации") |
| `HomeMetricsView.swift` | Последние значения АД и веса с датами |
| `HomeEventsView.swift` | Ближайший визит и дата анализа с бейджами (сегодня/завтра/через N дней) |
| `HomeQuoteView.swift` | Мотивационная цитата (ротация по дню года из `Quotes.swift`) |
| `HomeMedicationsView.swift` | Расписание лекарств на сегодня для главного экрана |
| `IndicatorsView.swift` | Графики АД/пульса/веса + активные кастомные метрики, фильтры 7/30/все; `ChartPeriod` picker |
| `BloodPressureCardView.swift` | Карточка с графиком систолического/диастолического + пульс |
| `PulseCardView.swift` | Карточка с графиком пульса |
| `WeightCardView.swift` | Карточка с графиком веса |
| `BloodPressureListView.swift` | Полная история измерений АД + редактирование + PDF экспорт |
| `WeightListView.swift` | Полная история измерений веса + редактирование + PDF экспорт |
| `LabResultsView.swift` | Список отслеживаемых анализов, опции экспорта (один/все) |
| `LabTestDetailView.swift` | Детали анализа: график, статистика, история, редактирование норм, PDF |
| `AddTrackedLabTestSheet.swift` | Добавление анализа из каталога или кастомного; защита от дублей |
| `LabTestCatalog.swift` | 16 предустановленных анализов с референсными значениями |
| `CustomMetricCatalog.swift` | 7 предустановленных кастомных метрик здоровья |
| `MedicationsView.swift` | Расписание приёма лекарств по времени, чекбоксы, свайп (удалить/изменить), PDF |
| `MedicationScheduleComponents.swift` | Общие компоненты: `MedicationTodayProgressCard`, `MedicationTimeSlotHeader`, `MedicationScheduleRow`, `MedicationScheduleFormat` |
| `DoctorVisitsView.swift` | История визитов к врачу по месяцам, свайп-удаление |
| `DoctorVisitDetailView.swift` | Детали визита: врач, дата, заметки; редактирование |
| `AddDoctorVisitView.swift` | Добавление/редактирование записи о визите |
| `DoctorAppointmentSheet.swift` | Запись следующего визита + интеграция с EventKit |
| `LabTestSheet.swift` | Дата следующего анализа + интеграция с EventKit |
| `SettingsView.swift` | Личные данные, статус лечения, переключатели уведомлений с пикерами времени, управление кастомными метриками |
| `AddCustomMetricView.swift` | Создание кастомной метрики: имя, единица, иконка (сетка SF Symbols, 6 колонок) |
| `CustomMetricCardView.swift` | Карточка кастомной метрики: график LineMark+catmullRom, пустое состояние, переход в историю |
| `AddCustomMetricEntrySheet.swift` | Добавление записи кастомной метрики: значение (decimalPad) + дата/время |
| `CustomMetricListView.swift` | История записей кастомной метрики по месяцам, свайп-удаление, PDF экспорт со статистикой |
| `ShareSheet.swift` | `UIViewControllerRepresentable` → `UIActivityViewController` |
| `ContentPlaceholderView.swift` | Заглушка пустых состояний |

### Models (SwiftData)

| Модель | Поля |
|--------|------|
| `UserProfile` | `categoryRaw: String`, `name: String`, `lastName: String?`, `age: Int?`, `birthDate: Date`, `patientPhone: String?`, `doctorPhone: String?`, `doctorName: String?`, `photoData: Data?`, `hemoStartDate/EndDate: Date?`, `hemoOngoing: Bool`, `pdStartDate/EndDate: Date?`, `pdOngoing: Bool`, `transplantDate: Date?`, `nextDoctorAppointment: Date?`, `nextDoctorName: String?`, `nextLabTest: Date?`, `hasCompletedOnboarding: Bool`; computed `category: UserCategory` |
| `BloodPressure` | `systolic: Int`, `diastolic: Int`, `pulse: Int`, `date: Date` |
| `Weight` | `valueKg: Double`, `date: Date` |
| `LabResult` | `name: String`, `value: Double`, `unit: String`, `date: Date`, `trackedTest: TrackedLabTest?` |
| `TrackedLabTest` | `name: String`, `unit: String`, `referenceMin: Double?`, `referenceMax: Double?`, `isCustom: Bool`, `createdAt: Date`, `results: [LabResult]` (cascade) |
| `Medication` | `name: String`, `dosageAmount: Double?`, `dosageUnit: String`, `daysOfWeek: [Int]`, `time: Date`, `isActive: Bool`, `intakes: [MedicationIntake]` (cascade); computed `formattedDosage: String` |
| `MedicationIntake` | `date: Date`, `isTaken: Bool`, `medication: Medication` |
| `WellBeing` | `weakness: Int`, `headache: Int`, `swelling: Int`, `date: Date` (шкала 1–5) |
| `DoctorVisit` | `id: UUID`, `date: Date`, `doctorName: String?`, `notes: String?`, `createdAt: Date` |
| `CustomMetric` | `id: UUID`, `name: String`, `unit: String`, `icon: String`, `isActive: Bool`, `isCustom: Bool`, `sortOrder: Int`, `entries: [CustomMetricEntry]` (cascade), `createdAt: Date` |
| `CustomMetricEntry` | `id: UUID`, `value: Double`, `date: Date`, `metric: CustomMetric?` |

### Utils

| Файл | Содержимое |
|------|-----------|
| `NotificationManager.swift` | Синглтон `shared`. Методы: `requestAuthorizationIfNeeded()`, `rescheduleMedicationNotifications(for:)`, `scheduleDoctorAppointmentNotification(date:doctorName:)`, `scheduleLabTestNotification(date:)`, `scheduleMeasurementReminders()`, `updateNotifications()`, `disableMedicationNotifications()`. Группирует уведомления о лекарствах по (weekday, time). Поддерживает критические уведомления. |
| `DateFormatters.swift` | `russianDate` ("d MMMM yyyy"), `russianDateTime` ("d MMMM yyyy, HH:mm"), `russianTime` ("HH:mm"), `russianMonthYear` ("LLLL yyyy"), `russianShortDate` ("d MMM"), `fileDate` ("yyyy-MM-dd"), `russianMonthSymbols: [String]` |

### Файлы данных

| Файл | Содержимое |
|------|-----------|
| `Quotes.swift` | `allQuotes: [DailyQuote]` — ~75 цитат на русском. Можно добавлять. |
| `LabTestCatalog.swift` | `predefinedLabTests` — 16 анализов (почки, электролиты, кровь, печень, иммуносупрессия). Можно добавлять. |
| `CustomMetricCatalog.swift` | `predefined: [CustomMetricDefinition]` — 7 метрик: Шаги, Активность, Вода, Сон, Температура, Сатурация, Уровень сахара |
| `AppMigrationPlan.swift` | SchemaV1 (9 моделей) → SchemaV2 (+CustomMetric, +CustomMetricEntry), lightweight-миграция, `typealias CurrentSchema = SchemaV2` |
| `PreviewData.swift` | Тестовые данные для Xcode Preview |
| `RenalTrackerApp.swift` | `@main`, ModelContainer через `AppMigrationPlan`, запрос разрешений на уведомления |

---

## Дизайн-система

### Карточки
```swift
.background(Color(.secondarySystemBackground))
.cornerRadius(16)
.overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
```

### Кнопки в NavigationBar (32×32)
```swift
// Экспорт / вторичное действие
ZStack {
    Circle().fill(Color(.secondarySystemBackground)).frame(width: 32, height: 32)
    Image(systemName: "square.and.arrow.up")
        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
}

// Добавить / основное действие
ZStack {
    Circle().fill(Color.blue.opacity(0.15)).frame(width: 32, height: 32)
    Image(systemName: "plus")
        .font(.system(size: 16, weight: .semibold)).foregroundStyle(.blue)
}
```

### Типографика
- Основной текст: `.font(.system(size: 15, weight: .medium))`
- Вторичный текст: `.font(.system(size: 13))` + `.foregroundStyle(.secondary)`
- Метки секций: `.font(.system(size: 11, weight: .medium))` + `.foregroundStyle(.secondary)`

### Списки
```swift
.listStyle(.insetGrouped)
.scrollContentBackground(.hidden)
```

### Временны́е заголовки секций
```swift
HStack(spacing: 8) {
    Text(timeString)
        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
    Rectangle().fill(Color(.separator)).frame(height: 0.5)
}
.textCase(nil)
```

### Прогресс-бар
```swift
// Используй готовый компонент:
MedicationTodayProgressCard(takenCount: takenCount, totalCount: totalCount)
```

### Свайп-действия (List только)
```swift
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) { ... } label: { Label("Удалить", systemImage: "trash") }
    Button { ... } label: { Label("Изменить", systemImage: "pencil") }
        .tint(.blue)
}
```

### Чекбокс (onTapGesture, не Button)
```swift
ZStack {
    Circle()
        .stroke(isTaken ? Color.green : Color(.separator), lineWidth: 1.5)
        .frame(width: 26, height: 26)
    if isTaken {
        Image(systemName: "checkmark")
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.green)
    }
}
.contentShape(Circle())
.onTapGesture { withAnimation(.easeInOut(duration: 0.15)) { toggle() } }
```

---

## Ключевые правила

- **Даты** — только через `DateFormatters.swift`, никаких локальных `DateFormatter()`
- **swipeActions** — работают только в `List`, не в `ScrollView`/`VStack`
- **Язык** — весь текст интерфейса на русском
- **Производительность** — не использовать `.tracking()` и `.kerning()`
- **Timer** — всегда инвалидировать в `.onDisappear`
- **Уведомления** — вызывать `rescheduleMedicationNotifications` только в `.onAppear`/`.onChange`, не в `body`
- **SwiftData** — `@Query` только в View; бизнес-логику выносить в методы View
- **DatePicker** — не закрывать автоматически через `onChange`; пикер остаётся открытым до нажатия "Сохранить"/"Отмена"
- **xcodebuild** — никогда не запускать

---

## Известные проблемы и решения

| Проблема | Решение |
|----------|---------|
| Чёрная полоса при свайпе в List | Использовать `listRowBackground(Color(.secondarySystemBackground))` на самой строке, не `.background()` |
| List не скругляет секции | Использовать `.listStyle(.insetGrouped)`, не `.plain` |
| Строка растягивается при свайпе | Добавить `listRowInsets(EdgeInsets(top:0,leading:16,bottom:0,trailing:16))` явно |
| DatePicker закрывался при выборе | Удалены все `onChange { showDatePicker = false }` из 7 файлов |
| Дублирование Timer на re-appear | Инвалидировать в `.onDisappear`, проверять `refreshTimer == nil` в `.onAppear` |

---

## Схема миграции SwiftData

```
SchemaV1 (1.0.0)          SchemaV2 (2.0.0)
─────────────────    →    ──────────────────────────
UserProfile               UserProfile
BloodPressure             BloodPressure
Weight                    Weight
LabResult                 LabResult
Medication                Medication
MedicationIntake          MedicationIntake
WellBeing                 WellBeing
TrackedLabTest            TrackedLabTest
DoctorVisit               DoctorVisit
                    +     CustomMetric
                    +     CustomMetricEntry
```

Тип миграции: `.lightweight` — новые таблицы, существующие данные не затрагиваются.

---

## Git
Коммитить после каждого значимого изменения.
