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
- Лекарства: расписание, отметка приёма, свайп-действия, PDF экспорт с разбивкой по времени приёма
- Визиты к врачу: история, детали, добавление/редактирование
- Настройки: профиль, статус лечения, уведомления, управление кастомными метриками
- Уведомления: лекарства, АД, вес, визиты, анализы
- Каталог кастомных метрик (CustomMetricCatalog, 7 метрик)
- SwiftData версионирование отложено до первого релиза; `ModelContainer` использует прямой `Schema([...])` со всеми 11 моделями, без `migrationPlan`

- **CustomMetrics UI** — полностью реализован:
  - SettingsView: раздел "ДОПОЛНИТЕЛЬНЫЕ ПОКАЗАТЕЛИ" — включение/выключение из каталога, добавление своих
  - IndicatorsView: карточки активных метрик с графиком (LineMark+catmullRom), синхронизированный ChartPeriod picker
  - CustomMetricListView: история записей по месяцам, свайп-удаление, PDF экспорт со статистикой
  - AddCustomMetricEntrySheet: ввод значения + дата/время
  - AddCustomMetricView: создание кастомной метрики (имя, единица, иконка из сетки SF Symbols)

- **Рефакторинг MedicationsView** (4 шага без изменения поведения):
  - `WeekdayPickerView` — выделен в `Views/Medications/WeekdayPickerView.swift`, устранено дублирование ~70 строк
  - `MedicationsPDFExporter` — вынесен в отдельный `enum`, `MedicationsView` избавился от `import PDFKit/UIKit`
  - `medicationRow(med:)` — инлайн-строка списка вынесена в `@ViewBuilder` func
  - `emptyStateView` — пустое состояние вынесено в `@ViewBuilder var`

- **Рефакторинг общей инфраструктуры**:
  - `ContentView` — убрано мерцание OnboardingView при cold start: удалён промежуточный `@State`, проверка теперь напрямую из `@Query`
  - `MedicationScheduleCalculator` — чистый value-type struct, устранено дублирование логики расписания (`todaysMedications`, `todayScheduleGroups`, `intakeForToday`, `takenCount`, `allTaken`, `nextUpcomingGroup`) из HomeView и MedicationsView. Инъекция `now` и `calendar` для тестируемости.
  - `SettingsView` разбит на 5 файлов в `Views/Settings/`: контейнер + 4 секции (Personal/Treatment/Notifications/CustomMetrics); с 743 строк до ~200 × 4
  - `AppStorageKeys` enum — все UserDefaults-ключи типизированы, защита от опечаток. Удалён мёртвый ключ `hasCompletedOnboarding` из OnboardingView.
  - `NotificationManager` state-free: методы `scheduleMeasurementReminders(_:)`, `updateNotifications(enabled:critical:)`, `rescheduleMedicationNotifications(for:enabled:critical:)` принимают настройки явно как параметры. Устранена скрытая race condition при вызове из `.onChange`. Новая value-type `ReminderSettings` бандлит 5 настроек. NotificationManager больше не зависит от UserDefaults/AppStorageKeys.
  - Удалён мёртвый кэш `_scheduledMedIDs` и метод `medicationIdentifiers()` из NotificationManager.

- **Универсальная PDF-инфраструктура**:
  - `Utils/PDFExport/PDFReportRenderer` — низкоуровневый A4-рендерер, единое место шрифтов/геометрии. Методы: `drawHeader(reportTitle:patientName:periodDescription:)`, `drawChart(_:height:)`, `drawTable(headers:columnWidthFractions:rows:monospaced:)`, `drawSectionTitle`, `drawLines`, `drawStats`, `beginNewPageIfNeeded`, `spacer`. Параметр `monospaced: Bool = true` (false для текстовых таблиц типа лекарств).
  - `Utils/PDFExport/PDFExporter` — обёртка над `UIGraphicsPDFRenderer` + сохранение в /tmp. `makeData(draw:)` и `saveToTempFile(data:fileNamePrefix:)`.
  - 6 конкретных exporter'ов (`BloodPressure`, `Weight`, `CustomMetric`, `LabTestDetail`, `LabResults`, `Medications`), каждый ~40-50 строк. Единая шапка: «Отчёт по X / Пациент: ФИО / Период: … / Сформировано: …».
  - `PDFLabChartView` — общий SwiftUI-чарт для лабораторных PDF, принимает value-type `[Point]`, выносится в UIImage через `ImageRenderer` на главном потоке.
  - Value-snapshot паттерн везде: @Model-объекты не пересекают границу `Task.detached`, только String/Double/Date.
  - Alert «Не удалось сформировать отчёт» при любой ошибке экспорта во всех 6 view (вместо молчания).
  - Alert «Нет данных за выбранный период» в 5 view при пустом фильтре (вместо молчаливого `guard`).
  - Инлайн-код генерации PDF в View удалён (~300 строк). `import PDFKit` / `import UIKit` ушли из 4 View.
  - MedicationsPDFExporter: разбивка по времени приёма — каждая группа в отдельной секции с заголовком времени, таблица (Препарат / Дозировка).

- **Единый компонент пустых состояний** — `EmptyStatePlaceholder`: эмодзи в голубом круге + заголовок + описание + tinted-кнопка. Используется в DoctorVisitsView (🏥), MedicationsView (💊), LabResultsView (🧪). Старый стиль (`largeTitle` + `buttonStyle(.borderedProminent)`) полностью удалён.

- Переименование вкладки "Показатели" → "Метрики" во всех 6 файлах

### В работе / Незавершено

Архитектурное решение: приложение в финале состоит из трёх условных частей по категориям пациентов (постпересадка, гемодиализ, перитонеальный диализ). Каждая категория имеет свой главный экран и свои специфические данные. Общие модули (метрики, анализы, лекарства, журнал) переиспользуются между категориями, со специализацией там где нужно.

Текущий фокус разработки — **постпересадочная часть**.

#### План постпересадки (в порядке выполнения)

1. Разделение HomeView на три view по категории (HomeViewTransplant, HomeViewHemo, HomeViewPD). На старте — все три одинаковые, основа для дальнейшей специализации.
2. Дизайн HomeViewTransplant в новом стиле: крупный счётчик дней с трансплантации, прогресс-бар вех (1мес, 3мес, 6мес и далее динамически), карточки с лекарствами, метриками, событиями. Реактивные мелочи — короткие фразы привязанные к фактам в данных, без кофейного коучинга.
3. Архитектура Журнала: новые модели WellbeingEntry и ThoughtEntry, удаление неиспользуемой WellBeing. DoctorVisit остаётся как есть.
4. Каталог симптомов SymptomCatalog с 9 предустановленными (слабость, головная боль, тошнота, озноб, отёки, боль в животе, боль в спине, бессонница, тревога) + возможность добавить свой.
5. Экран Журнал — заменяет вкладку Приёмы. Хронологическая лента трёх типов записей. Приёмы у врача визуально выделены как «вехи», между ними — мелкие записи самочувствия и мыслей.
6. UI создания записи самочувствия: ползунок 1-5 («плохо — хорошо», только концы подписаны), сетка чипов с симптомами (как в WeekdayPickerView).
7. UI создания записи мысли: дата + поле для свободного текста.
8. Детальная карточка приёма у врача со сводкой за период с предыдущего приёма (среднее самочувствие, частые симптомы, мысли, тренды критических анализов). Никаких ручных привязок — связь через даты.

#### Backlog: гемодиализ

- Модель DialysisSession (параметры сеанса: длительность, скорость потока крови Qb, UF rate, объём УФ, тип диализатора)
- Расписание сеансов (когда следующий)
- Сухой вес и междиализная прибавка
- АД до/после сеанса (отдельные значения)
- Дневник эпизодов на сеансе (головная боль, судороги, гипотензия)
- Опциональная метрика «состояние фистулы»
- HomeViewHemo с фокусом на: расписание, прибавка, ближайший сеанс

#### Backlog: перитонеальный диализ

- Тип режима в профиле (циклер / ручные обмены) — определяется на onboarding
- Кнопка «Начать процедуру» на главном экране + пошаговые чек-листы по типу
- Модель обмена: тип, залито мл, слито мл, вес до/после, время
- Авто-расчёт УФ за обмен и сумма за день
- График баланса жидкости по дням
- Уведомления за 10 минут до запланированного обмена
- Расписание обменов (3-4 ручных или один циклер)
- HomeViewPD с фокусом на: ближайший обмен, баланс дня, состояние exit site (опционально)

#### Backlog: общее (после фокусной части)

- Базовые юнит-тесты (MedicationScheduleCalculator, NotificationManager, PDF exporter'ы)
- Доступность (accessibility labels, support for VoiceOver)
- Локализация (английский интерфейс)
- AppMigrationPlan для SwiftData перед релизом
- ИИ-сводка по данным пациента (большая отдельная фича со своими юридическими и техническими вопросами — приватность медицинских данных, регуляторика, дисклеймеры)

#### Принципы тона приложения

Эти принципы определялись в обсуждении с автором (Роберт Зинятуллин), который сам прошёл путь пациента: 13 месяцев на ПД, 1 месяц на ГД, трансплантация в январе 2026.

- Тон спокойный, без вау-эмодзи и фитнес-восторгов. Ближе к старому врачу, чем к коучу.
- Никаких прогнозов про ухудшение — пациент до последнего надеется на улучшение, и приложение не должно эту надежду подрывать.
- Реактивные фразы — только на достоверных данных, и редко. Большую часть времени приложение молчит.
- Текст для пациента (фразы, формулировки, описания симптомов) проверяется автором или консультирующим врачом. Промпты дают placeholder-варианты, финал утверждает автор.
- Главное в нашей нише — не «достичь цели и побить рекорд», а признание упорства и стабильности. У хронического пациента нет «лучше», есть «стабильно», и стабильность — уже победа.
- Приложение должно усиливать связь пациент-врач, а не заменять её.

---

## Структура проекта

### Views

| Файл | Назначение |
|------|-----------|
| `ContentView.swift` | Корневой view: онбординг или MainTabView; проверка `profiles.contains(where: hasCompletedOnboarding)` напрямую из `@Query` |
| `MainTabView.swift` | TabView с 5 вкладками |
| `OnboardingView.swift` | 5-шаговый онбординг: 3 intro-слайда, личные данные, статус лечения |
| `HomeView.swift` | Дашборд: приветствие, последние метрики, лекарства на сегодня, события, цитата; Timer каждые 60 сек. Использует `MedicationScheduleCalculator` с `now: currentTime`. |
| `HomeGreetingView.swift` | Приветствие + имя + статус ("День N после трансплантации") |
| `HomeMetricsView.swift` | Последние значения АД и веса с датами |
| `HomeEventsView.swift` | Ближайший визит и дата анализа с бейджами |
| `HomeQuoteView.swift` | Мотивационная цитата (ротация по дню года из `Quotes.swift`) |
| `HomeMedicationsView.swift` | Расписание лекарств на сегодня для главного экрана |
| `IndicatorsView.swift` | Графики АД/пульса/веса + активные кастомные метрики, фильтры 7/30/все |
| `BloodPressureCardView.swift` | Карточка с графиком систолического/диастолического + пульс |
| `PulseCardView.swift` | Карточка с графиком пульса |
| `WeightCardView.swift` | Карточка с графиком веса |
| `BloodPressureListView.swift` | История АД + редактирование + PDF через `BloodPressurePDFExporter` |
| `WeightListView.swift` | История веса + редактирование + PDF через `WeightPDFExporter` |
| `LabResultsView.swift` | Список отслеживаемых анализов, опции экспорта (один/все) через `LabResultsPDFExporter` и `LabTestDetailPDFExporter`. Empty state через `EmptyStatePlaceholder` (🧪) |
| `LabTestDetailView.swift` | Детали анализа: график, статистика, история, редактирование норм, PDF через `LabTestDetailPDFExporter` |
| `AddTrackedLabTestSheet.swift` | Добавление анализа из каталога или кастомного; защита от дублей |
| `LabTestCatalog.swift` | 16 предустановленных анализов с референсными значениями |
| `CustomMetricCatalog.swift` | 7 предустановленных кастомных метрик здоровья |
| `MedicationsView.swift` | Расписание приёма лекарств по времени, чекбоксы, свайп, PDF через `MedicationsPDFExporter`. Использует `MedicationScheduleCalculator`. Содержит `AddMedicationSheet`, `EditMedicationSheet`. Empty state через `EmptyStatePlaceholder` (💊). `@AppStorage` для notifications/critical toggle |
| `MedicationScheduleComponents.swift` | Общие компоненты: `MedicationTodayProgressCard`, `MedicationScheduleFormat`, `MedicationScheduleCopy` |
| `Medications/WeekdayPickerView.swift` | Пикер дней недели (`@Binding<Set<Int>>`); `WeekdayOption` и `allWeekdayOptions` определены здесь — единственное место в проекте |
| `Settings/SettingsView.swift` | Контейнер: NavigationStack, toolbar, save, alert смены категории. Держит общий `@State` (имя, статус лечения, даты) и прокидывает биндинги в секции. |
| `Settings/SettingsPersonalSection.swift` | Секция "ЛИЧНЫЕ ДАННЫЕ" (имя, фамилия) |
| `Settings/SettingsTreatmentSection.swift` | Секция "СТАТУС ЛЕЧЕНИЯ" (категория + даты) |
| `Settings/SettingsNotificationsSection.swift` | Секция "УВЕДОМЛЕНИЯ" — полностью автономна через `@AppStorage` и `@State` для времён. Собирает `ReminderSettings` из текущих значений для передачи в `NotificationManager`. |
| `Settings/SettingsCustomMetricsSection.swift` | Секция "ДОПОЛНИТЕЛЬНЫЕ ПОКАЗАТЕЛИ" — `@Query` + инициализация предустановленных в `.onAppear` |
| `DoctorVisitsView.swift` | История визитов по месяцам, свайп-удаление. Empty state через `EmptyStatePlaceholder` (🏥) |
| `DoctorVisitDetailView.swift` | Детали визита: врач, дата, заметки; редактирование |
| `AddDoctorVisitView.swift` | Добавление/редактирование записи о визите |
| `DoctorAppointmentSheet.swift` | Запись следующего визита + интеграция с EventKit |
| `LabTestSheet.swift` | Дата следующего анализа + интеграция с EventKit |
| `AddCustomMetricView.swift` | Создание кастомной метрики: имя, единица, иконка (сетка SF Symbols) |
| `CustomMetricCardView.swift` | Карточка кастомной метрики: график LineMark+catmullRom, пустое состояние |
| `AddCustomMetricEntrySheet.swift` | Добавление записи: значение (decimalPad) + дата/время |
| `CustomMetricListView.swift` | История записей по месяцам, свайп-удаление, PDF через `CustomMetricPDFExporter` |
| `EmptyStatePlaceholder.swift` | Единый компонент пустого состояния: emoji/title/description/buttonTitle/action. Геометрия: круг 80×80 `Color.blue.opacity(0.1)`, эмодзи 36pt, кнопка tinted (blue text on `Color.blue.opacity(0.1)` background, cornerRadius 12). |
| `ShareSheet.swift` | `UIViewControllerRepresentable` → `UIActivityViewController` |
| `ContentPlaceholderView.swift` | Простой текстовый placeholder (не empty state — для заглушек-филлеров) |

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
| `AppStorageKeys.swift` | `enum AppStorageKeys` с типизированными строковыми константами: `notificationsEnabled`, `criticalNotificationsEnabled`, `bpReminderEnabled`, `weightReminderEnabled`, `bpMorningReminderTime`, `bpEveningReminderTime`, `weightReminderTime`, `doctorCalendarAddedTimestamp`, `labCalendarAddedTimestamp`. Использовать во всех `@AppStorage(...)` и `UserDefaults.standard.*(forKey:)`. |
| `MedicationScheduleCalculator.swift` | Чистый value-type struct без SwiftUI. Принимает `[Medication]`, `[MedicationIntake]`, `now: Date` (инъектируемый), `calendar: Calendar`. Публикует: `todaysMedications`, `todayScheduleGroups` (группы по hour+minute), `intakeForToday(for:)`, `isTaken(_:)`, `takenCount`, `totalCount`, `allTaken`, `nextUpcomingGroup`. Пересоздаётся в каждом body. |
| `NotificationManager.swift` | Синглтон `shared`. Не зависит от UserDefaults/AppStorageKeys — все настройки передаются параметрами. Методы: `requestAuthorizationIfNeeded()`, `rescheduleMedicationNotifications(for:enabled:critical:)`, `scheduleDoctorAppointmentNotification(date:doctorName:)`, `scheduleLabTestNotification(date:)`, `scheduleMeasurementReminders(_ settings: ReminderSettings)`, `updateNotifications(enabled:critical:)`, `disableMedicationNotifications()`, `printScheduledNotifications()`. Группирует уведомления о лекарствах по (weekday, hour, minute). Поддерживает `.timeSensitive` для критических. `ReminderSettings` — value-type struct с 5 настройками. |
| `DateFormatters.swift` | `russianDate`, `russianDateTime`, `russianTime`, `russianMonthYear`, `russianShortDate`, `fileDate`, `russianMonthSymbols: [String]` |

### Utils/PDFExport

| Файл | Содержимое |
|------|-----------|
| `PDFReportRenderer.swift` | Низкоуровневый A4-рендерер. Init принимает `UIGraphicsPDFRendererContext` + margin (32 по умолчанию). Единое место шрифтов: title 20pt bold, subtitle 12pt, section 14pt semibold, header 12pt semibold, row 11pt monospaced. Методы: `drawHeader(reportTitle:patientName:periodDescription:)` рисует унифицированную шапку; `drawChart(_ image:height:)`; `drawTable(headers:columnWidthFractions:rows:monospaced:)` — пагинация с повтором заголовков, `monospaced: Bool = true` (false для текстовых таблиц); `drawSectionTitle(_:)`; `drawLines(_:)`; `drawStats(title:lines:)`; `beginNewPageIfNeeded(reserving:)`; `spacer(_:)`. |
| `PDFExporter.swift` | Обёртка над `UIGraphicsPDFRenderer`. `makeData(margin:draw:) -> Data` — замыкание получает `PDFReportRenderer`. Thread-safe, можно из `Task.detached`. `saveToTempFile(data:fileNamePrefix:) throws -> URL` — санитизация имени (замена `/` и пробелов) + UUID. |
| `PDFLabChartView.swift` | Общий SwiftUI `Chart` для лабораторных PDF. Принимает `[Point]` value-type. Рендерится в `UIImage` через `ImageRenderer` на главном потоке. |
| `BloodPressurePDFExporter.swift` | `struct Record { date, systolic, diastolic, pulse }` + `makeData(records:periodDescription:patientName:)`. Таблица 5 колонок, итоги мин/макс/среднее по трём метрикам. |
| `WeightPDFExporter.swift` | `struct Record { date, valueKg }` + `makeData(records:periodDescription:patientName:)`. Таблица 2 колонки, итоги мин/макс/среднее. |
| `CustomMetricPDFExporter.swift` | `struct Entry { date, value }` + `makeData(metricName:unit:entries:patientName:)`. Итоги с количеством записей. |
| `LabTestDetailPDFExporter.swift` | `struct Result { date, value }` + `makeData(testName:unit:results:periodDescription:patientName:chartImage:)`. График опциональный (≥ 2 точек). Единая шапка «Отчёт по анализу: X». Используется и в LabTestDetailView, и в LabResultsView. |
| `LabResultsPDFExporter.swift` | `struct Test { name, unit, results: [LabTestDetailPDFExporter.Result] }` + `makeData(tests:patientName:)`. Многосекционный отчёт, каждый тест — своя секция с таблицей. Без графиков. |
| `MedicationsPDFExporter.swift` | `struct Row { name, dosage, time }` + `generateData(rows:patientName:) -> Data?` + `fileURL(from:) throws -> URL`. Разбивка по времени приёма: сортировка по time, `drawSectionTitle` для каждой группы, таблица 2 колонки (Препарат / Дозировка) с `monospaced: false`. |

### Файлы данных

| Файл | Содержимое |
|------|-----------|
| `Quotes.swift` | `allQuotes: [DailyQuote]` — ~75 цитат на русском |
| `LabTestCatalog.swift` | `predefinedLabTests` — 16 анализов (почки, электролиты, кровь, печень, иммуносупрессия) |
| `CustomMetricCatalog.swift` | `predefined: [CustomMetricDefinition]` — 7 метрик: Шаги, Активность, Вода, Сон, Температура, Сатурация, Уровень сахара |
| `RenalTrackerApp.swift` | `@main`, ModelContainer с прямым `Schema([11 моделей])`, roadmap-комментарий версионирования перед релизом. В `.task` читает `UserDefaults.standard` один раз (нет owner'а `@AppStorage` на этом уровне) и вызывает `updateNotifications(enabled:critical:)`. |
| `PreviewData.swift` | Тестовые данные для Xcode Preview |

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

### Empty state
Всегда через компонент `EmptyStatePlaceholder`:
```swift
EmptyStatePlaceholder(
    emoji: "💊",
    title: "Нет лекарств в расписании",
    description: "Добавьте первое лекарство,\nчтобы видеть расписание приёма",
    buttonTitle: "Добавить первое лекарство",
    action: { isShowingAddMedication = true }
)
```
Описание обычно разбивается на 2 строки через `\n`. Эмодзи подбирается под экран: 💊 (Лекарства), 🧪 (Анализы), 🏥 (Приёмы). Не используй `largeTitle` и `buttonStyle(.borderedProminent)` для пустых состояний — это старый стиль.

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
    Circle().stroke(isTaken ? Color.green : Color(.separator), lineWidth: 1.5)
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
- **UserDefaults-ключи** — только через `AppStorageKeys.*`, никаких строковых литералов
- **Empty state** — только через `EmptyStatePlaceholder` (эталонный компонент)
- **swipeActions** — работают только в `List`, не в `ScrollView`/`VStack`
- **Язык** — весь текст интерфейса на русском
- **Производительность** — не использовать `.tracking()` и `.kerning()`
- **Timer** — всегда инвалидировать в `.onDisappear`
- **SwiftData + Task.detached** — `@Model`-объекты НЕ пересекают границу detached. Делать value-snapshot на главном потоке (struct с примитивами), передавать его в detached.
- **NotificationManager** — все настройки передаются параметрами, методы НЕ читают `UserDefaults` изнутри
- **SwiftData** — `@Query` только в View; бизнес-логику выносить в чистые value-type калькуляторы типа `MedicationScheduleCalculator`
- **DatePicker** — не закрывать автоматически через `onChange`; пикер остаётся открытым до нажатия "Сохранить"/"Отмена"
- **PDF** — все отчёты через `PDFReportRenderer` + `PDFExporter`. Шапка единая: `drawHeader(reportTitle:patientName:periodDescription:)`. Никаких `UIGraphicsPDFRenderer` / `NSString.draw` в View.
- **xcodebuild** — никогда не запускать

---

## Известные проблемы и решения

| Проблема | Решение |
|----------|---------|
| Чёрная полоса при свайпе в List | Использовать `listRowBackground(Color(.secondarySystemBackground))` на самой строке, не `.background()` |
| List не скругляет секции | Использовать `.listStyle(.insetGrouped)`, не `.plain` |
| Строка растягивается при свайпе | Добавить `listRowInsets(EdgeInsets(top:0,leading:16,bottom:0,trailing:16))` явно |
| DatePicker закрывался при выборе | Удалены все `onChange { showDatePicker = false }` |
| Дублирование Timer на re-appear | Инвалидировать в `.onDisappear`, проверять `refreshTimer == nil` в `.onAppear` |
| ContentView flash OnboardingView при cold start | Убрано промежуточное `@State`, проверка `profiles.contains(where:)` прямо в body |
| CustomMetric PDF белый экран | `@Model`-объекты не пересекают границу `Task.detached`. Value-snapshot до detached. |
| Multiple commands produce при перемещении файлов | После переноса файла в другую папку: проверить, что старая ссылка удалена из Xcode-navigator (красный файл — Remove Reference), Clean Build Folder |
| Xcode file not found после `git pull` | Новые файлы, добавленные через правку `project.pbxproj` руками, иногда нужно Clean + DerivedData очистить |
| Тон, формулировки, тексты для пациента | Финальные тексты утверждает автор (Роберт). Промпты от Claude дают placeholder-варианты для согласования, не финальный текст для продакшена |

---

## SwiftData: версионирование схемы (roadmap к релизу)

Версионирование (`VersionedSchema` / `SchemaMigrationPlan`) отложено — приложение в разработке, реальных пользователей нет.

Текущий `ModelContainer` использует прямой `Schema([UserProfile, BloodPressure, Weight, LabResult, TrackedLabTest, Medication, MedicationIntake, WellBeing, DoctorVisit, CustomMetric, CustomMetricEntry])` без `migrationPlan`.

**Перед первым релизом в App Store:**
1. Создать `AppMigrationPlan.swift`: зафиксировать текущие модели как `SchemaV1` (вложенные `@Model`-копии)
2. Объявить `AppMigrationPlan: SchemaMigrationPlan` с пустым массивом stages
3. Передать `migrationPlan: AppMigrationPlan.self` в `ModelContainer`
4. Все последующие изменения моделей — через новые версии `SchemaVN` с новыми stages

---

## Git
Коммитить после каждого значимого изменения.