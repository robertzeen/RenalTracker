//
//  RenalTrackerApp.swift
//  RenalTracker
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct RenalTrackerApp: App {

    // MARK: - ModelContainer
    //
    // Версионирование схемы (VersionedSchema / SchemaMigrationPlan) отложено до первого релиза.
    // Пока приложение в разработке и реальных пользовательских данных нет, миграция не нужна.
    //
    // ⚠️ Перед релизом в App Store:
    //   1. Создай AppMigrationPlan.swift: зафиксируй текущие @Model-классы как SchemaV1
    //      (вложенные копии с теми же полями), объяви AppMigrationPlan: SchemaMigrationPlan
    //   2. Замени Schema([...]) ниже на Schema(CurrentSchema.models)
    //   3. Передай migrationPlan: AppMigrationPlan.self в ModelContainer
    //   4. Все последующие изменения моделей выполняй через новые версии SchemaVN

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            BloodPressure.self,
            Weight.self,
            LabResult.self,
            TrackedLabTest.self,
            Medication.self,
            MedicationIntake.self,
            DoctorVisit.self,
            WellbeingEntry.self,
            ThoughtEntry.self,
            CustomMetric.self,
            CustomMetricEntry.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    let center = UNUserNotificationCenter.current()
                    let granted = try? await center.requestAuthorization(
                        options: [.alert, .sound, .badge]
                    )
                    if let granted {
                        print("[Notifications] Authorization granted: \(granted)")
                    } else {
                        print("[Notifications] Authorization request failed")
                    }
                    await MainActor.run {
                        center.setBadgeCount(0) { error in
                            if let error {
                                print("[Notifications] setBadgeCount error: \(error)")
                            }
                        }
                    }
                    if granted == true {
                        await MainActor.run {
                            let enabled = UserDefaults.standard.object(forKey: AppStorageKeys.notificationsEnabled) as? Bool ?? true
                            let critical = UserDefaults.standard.bool(forKey: AppStorageKeys.criticalNotificationsEnabled)
                            NotificationManager.shared.updateNotifications(enabled: enabled, critical: critical)
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
