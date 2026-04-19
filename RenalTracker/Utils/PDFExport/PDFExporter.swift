//
//  PDFExporter.swift
//  RenalTracker
//
//  Высокоуровневая обёртка над UIGraphicsPDFRenderer и сохранением в /tmp.
//  Точка входа для всех конкретных exporter'ов приложения.
//

import Foundation
import UIKit

enum PDFExporter {

    // MARK: - Генерация данных

    /// Создаёт A4 PDF. Замыкание получает готовый PDFReportRenderer.
    /// Первая страница начинается автоматически.
    /// Thread-safe — можно вызывать из Task.detached.
    static func makeData(
        margin: CGFloat = PDFReportRenderer.defaultMargin,
        draw: (PDFReportRenderer) -> Void
    ) -> Data {
        let pageRect = CGRect(origin: .zero, size: PDFReportRenderer.pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { context in
            context.beginPage()
            let reportRenderer = PDFReportRenderer(context: context, margin: margin)
            draw(reportRenderer)
        }
    }

    // MARK: - Сохранение файла

    /// Сохраняет data в temporaryDirectory.
    /// К имени автоматически добавляется UUID, чтобы избежать коллизий.
    /// fileNamePrefix — короткий маркер для отладки: "BP", "Weight", "Lab-Creatinine".
    static func saveToTempFile(data: Data, fileNamePrefix: String) throws -> URL {
        let sanitized = fileNamePrefix
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitized)-\(UUID().uuidString).pdf")
        try data.write(to: url)
        return url
    }
}
