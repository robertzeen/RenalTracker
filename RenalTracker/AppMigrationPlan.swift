//
//  AppMigrationPlan.swift
//  RenalTracker
//
//  Версионирование SwiftData-схемы.
//  При добавлении новых моделей или полей:
//    1. Скопируй текущий enum SchemaVN в новый SchemaVN+1
//    2. Внеси изменения в новый enum
//    3. Добавь новую версию в AppMigrationPlan.schemas
//    4. Добавь .lightweight stage (или .custom если нужна трансформация данных)
//    5. Обнови typealias CurrentSchema
//

import SwiftData

// MARK: - Schema V1 (оригинальные 9 моделей)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [
        UserProfile.self,
        BloodPressure.self,
        Weight.self,
        LabResult.self,
        Medication.self,
        MedicationIntake.self,
        WellBeing.self,
        TrackedLabTest.self,
        DoctorVisit.self
    ]
}

// MARK: - Schema V2 (+ CustomMetric, CustomMetricEntry)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] = [
        UserProfile.self,
        BloodPressure.self,
        Weight.self,
        LabResult.self,
        Medication.self,
        MedicationIntake.self,
        WellBeing.self,
        TrackedLabTest.self,
        DoctorVisit.self,
        CustomMetric.self,
        CustomMetricEntry.self
    ]
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] = [
        SchemaV1.self,
        SchemaV2.self
    ]

    static var stages: [MigrationStage] = [
        // Лёгкая миграция V1 → V2: только новые модели, данные не затрагиваются
        .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)
    ]
}

// MARK: - Актуальная схема (всегда указывает на последнюю версию)

typealias CurrentSchema = SchemaV2
