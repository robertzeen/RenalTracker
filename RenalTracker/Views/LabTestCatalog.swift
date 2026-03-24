// Каталог отслеживаемых анализов
// Чтобы добавить новый анализ — добавь новую строку в массив predefined
// Формат: .init(name: "Название", unit: "ед.изм.", referenceMin: 0, referenceMax: 100)

import Foundation

struct LabTestDefinition: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let unit: String
    let referenceMin: Double?
    let referenceMax: Double?
}

enum LabTestCatalog {
    static let predefined: [LabTestDefinition] = [
        // --- Почечная функция ---
        .init(name: "Креатинин",           unit: "мкмоль/л", referenceMin: 60,   referenceMax: 120),
        .init(name: "Мочевина",            unit: "ммоль/л",  referenceMin: 2.5,  referenceMax: 8.3),
        .init(name: "Мочевая кислота",     unit: "мкмоль/л", referenceMin: 210,  referenceMax: 420),

        // --- Электролиты ---
        .init(name: "Калий",               unit: "ммоль/л",  referenceMin: 3.5,  referenceMax: 5.5),
        .init(name: "Кальций",             unit: "ммоль/л",  referenceMin: 2.15, referenceMax: 2.55),
        .init(name: "Фосфор",              unit: "ммоль/л",  referenceMin: 0.81, referenceMax: 1.45),

        // --- Кровь ---
        .init(name: "Гемоглобин",          unit: "г/л",      referenceMin: 110,  referenceMax: 140),
        .init(name: "Ферритин",            unit: "нг/мл",    referenceMin: 30,   referenceMax: 400),

        // --- Печёночные ферменты ---
        .init(name: "АЛТ",                 unit: "ед/л",     referenceMin: 40,   referenceMax: 55),
        .init(name: "АСТ",                 unit: "ед/л",     referenceMin: 40,   referenceMax: 47),
        .init(name: "Общий белок",         unit: "г/л",      referenceMin: 64,   referenceMax: 84),

        // --- Иммуносупрессия ---
        .init(name: "Такролимус",          unit: "пг/мл",    referenceMin: 5,    referenceMax: 15),
        .init(name: "Паратгормон",         unit: "пг/мл",    referenceMin: 15,   referenceMax: 65),

        // --- Прочее ---
        .init(name: "С-реактивный белок",  unit: "мг/л",     referenceMin: 0,    referenceMax: 5),
        .init(name: "Холестерин",          unit: "ммоль/л",  referenceMin: 0,    referenceMax: 5.2),
    ]
}
