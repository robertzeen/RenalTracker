//
//  CustomMetricCatalog.swift
//  RenalTracker
//
//  Каталог предустановленных метрик здоровья.
//  Чтобы добавить новую — добавь новый элемент в массив predefined.
//

import Foundation

struct CustomMetricDefinition {
    let name: String
    let unit: String
    let icon: String
    let sortOrder: Int
}

enum CustomMetricCatalog {
    static let predefined: [CustomMetricDefinition] = [
        // --- Активность ---
        .init(name: "Шаги",                  unit: "шт",       icon: "figure.walk",         sortOrder: 1),
        .init(name: "Физическая активность",  unit: "мин",      icon: "figure.run",          sortOrder: 2),

        // --- Питание и вода ---
        .init(name: "Вода",                  unit: "мл",       icon: "drop.fill",            sortOrder: 3),

        // --- Сон ---
        .init(name: "Сон",                   unit: "ч",        icon: "moon.fill",            sortOrder: 4),

        // --- Самочувствие ---
        .init(name: "Температура тела",      unit: "°C",       icon: "thermometer",          sortOrder: 5),
        .init(name: "Сатурация",             unit: "%",        icon: "waveform.path.ecg",    sortOrder: 6),
        .init(name: "Уровень сахара",        unit: "ммоль/л",  icon: "drop.triangle.fill",   sortOrder: 7),
    ]
}
