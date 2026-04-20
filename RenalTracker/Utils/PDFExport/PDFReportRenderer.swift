//
//  PDFReportRenderer.swift
//  RenalTracker
//
//  Низкоуровневый рендерер A4-отчётов. Не зависит от SwiftUI и SwiftData.
//  Единственное место, где задаются шрифты и геометрия всех PDF-отчётов.
//

import Foundation
import UIKit

final class PDFReportRenderer {

    // MARK: - Геометрия

    static let pageSize = CGSize(width: 595, height: 842)
    static let defaultMargin: CGFloat = 32

    private let context: UIGraphicsPDFRendererContext
    private let pageRect: CGRect
    private let margin: CGFloat
    private var y: CGFloat

    // MARK: - Шрифты (менять ТОЛЬКО здесь)

    private let titleFont    = UIFont.systemFont(ofSize: 20, weight: .bold)
    private let subtitleFont = UIFont.systemFont(ofSize: 12)
    private let sectionFont  = UIFont.systemFont(ofSize: 14, weight: .semibold)
    private let headerFont   = UIFont.systemFont(ofSize: 12, weight: .semibold)
    private let rowFont      = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)

    // MARK: - Init

    init(context: UIGraphicsPDFRendererContext, margin: CGFloat = defaultMargin) {
        self.context  = context
        self.pageRect = CGRect(origin: .zero, size: PDFReportRenderer.pageSize)
        self.margin   = margin
        self.y        = margin
    }

    // MARK: - Шапка

    /// Унифицированная шапка отчёта.
    /// Рисует: title (20pt bold), опционально "Пациент: ФИО",
    /// опционально "Период: …", "Сформировано: ДД месяц ГГГГ, ЧЧ:ММ".
    /// patientName nil или пустая — строка пациента пропускается.
    /// periodDescription nil — строка периода пропускается.
    /// Оставляет нижний отступ 16pt.
    func drawHeader(reportTitle: String, patientName: String?, periodDescription: String? = nil) {
        (reportTitle as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: titleFont]
        )
        y += 28

        var lines: [String] = []
        if let name = patientName?.trimmingCharacters(in: .whitespaces), !name.isEmpty {
            lines.append("Пациент: \(name)")
        }
        if let period = periodDescription {
            lines.append("Период: \(period)")
        }
        lines.append("Сформировано: \(DateFormatter.russianDateTime.string(from: Date()))")

        let subtitleText = lines.joined(separator: "\n")
        let rect = CGRect(x: margin, y: y,
                          width: pageRect.width - 2 * margin,
                          height: CGFloat(lines.count) * 16)
        (subtitleText as NSString).draw(in: rect, withAttributes: [.font: subtitleFont])
        y += CGFloat(lines.count) * 16 + 16
    }

    // MARK: - График

    /// Рисует UIImage графика. Ширина — весь контент страницы.
    /// Оставляет нижний отступ 16pt.
    func drawChart(_ image: UIImage, height: CGFloat) {
        image.draw(in: CGRect(x: margin, y: y,
                              width: pageRect.width - 2 * margin,
                              height: height))
        y += height + 16
    }

    // MARK: - Таблица

    /// Рисует таблицу с заголовочным рядом и строками данных.
    ///
    /// - columnWidthFractions: веса колонок (нормализуются внутри, сумма — любая).
    /// - rows: массив строк; длина каждой строки должна совпадать с headers.count.
    ///
    /// Автоматически переносит на новую страницу и повторяет заголовки.
    /// rowHeight фиксирован 16pt. Нижний отступ после таблицы 16pt.
    func drawTable(
        headers: [String],
        columnWidthFractions: [CGFloat],
        rows: [[String]],
        monospaced: Bool = true
    ) {
        guard headers.count == columnWidthFractions.count else { return }

        let contentWidth  = pageRect.width - 2 * margin
        let totalFractions = columnWidthFractions.reduce(0, +)
        let columnWidths  = columnWidthFractions.map { $0 / totalFractions * contentWidth }
        let rowFontToUse: UIFont = monospaced
            ? rowFont
            : UIFont.systemFont(ofSize: 11, weight: .regular)

        func drawHeaderRow() {
            var x = margin
            for (i, header) in headers.enumerated() {
                (header as NSString).draw(
                    in: CGRect(x: x, y: y, width: columnWidths[i], height: 16),
                    withAttributes: [.font: headerFont]
                )
                x += columnWidths[i]
            }
            y += 16 + 2
        }

        drawHeaderRow()

        for row in rows {
            if y > pageRect.height - margin - 20 {
                context.beginPage()
                y = margin
                drawHeaderRow()
            }
            var x = margin
            for (i, cell) in row.enumerated() where i < columnWidths.count {
                (cell as NSString).draw(
                    in: CGRect(x: x, y: y, width: columnWidths[i], height: 16),
                    withAttributes: [.font: rowFontToUse]
                )
                x += columnWidths[i]
            }
            y += 16
        }
        y += 16
    }

    // MARK: - Секция

    /// Заголовок секции 14pt semibold. Оставляет отступ 8pt (итого: 20 + 8 = 28pt).
    /// Автоматически начинает новую страницу если не хватает 40pt.
    func drawSectionTitle(_ text: String) {
        beginNewPageIfNeeded(reserving: 40)
        (text as NSString).draw(
            at: CGPoint(x: margin, y: y),
            withAttributes: [.font: sectionFont]
        )
        y += 20
    }

    /// Рисует строки 12pt по одной линии высотой 16pt каждая.
    /// Оставляет нижний отступ 8pt.
    func drawLines(_ lines: [String]) {
        beginNewPageIfNeeded(reserving: CGFloat(lines.count) * 16 + 8)
        for line in lines {
            (line as NSString).draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: subtitleFont]
            )
            y += 16
        }
        y += 8
    }

    /// Удобная обёртка: заголовок секции + строки статистики.
    func drawStats(title: String = "Итоги за период:", lines: [String]) {
        drawSectionTitle(title)
        drawLines(lines)
    }

    // MARK: - Управление страницами

    /// Начинает новую страницу если оставшаяся высота меньше reserving.
    func beginNewPageIfNeeded(reserving height: CGFloat) {
        if y > pageRect.height - margin - height {
            context.beginPage()
            y = margin
        }
    }

    /// Добавляет вертикальный отступ.
    func spacer(_ height: CGFloat) {
        y += height
    }
}
