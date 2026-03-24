//
//  DateFormatters.swift
//  RenalTracker
//

import Foundation

extension DateFormatter {
    static let russianDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy"
        return f
    }()

    static let russianDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM yyyy, HH:mm"
        return f
    }()

    static let russianTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let russianMonthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    /// "d MMM" — короткая дата для подписей на графиках (PDF)
    static let russianShortDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f
    }()

    /// "yyyy-MM-dd" — для имён PDF-файлов
    static let fileDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Русские названия месяцев (Январь…Декабрь) для онбординга
    static let russianMonthSymbols: [String] = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        return f.monthSymbols
    }()
}

