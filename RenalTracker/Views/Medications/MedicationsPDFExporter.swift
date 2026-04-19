//
//  MedicationsPDFExporter.swift
//  RenalTracker
//

import PDFKit
import UIKit

enum MedicationsPDFExporter {

    static func generateData(meds: [Medication], patientName: String) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "RenalTracker",
            kCGPDFContextAuthor as String: "RenalTracker"
        ]

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            _ = context.cgContext

            let margin: CGFloat = 40
            var y: CGFloat = 40

            let titleFont = UIFont.systemFont(ofSize: 20, weight: .bold)
            let subtitleFont = UIFont.systemFont(ofSize: 12, weight: .regular)
            let tableHeaderFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
            let tableCellFont = UIFont.systemFont(ofSize: 11, weight: .regular)
            let footerFont = UIFont.systemFont(ofSize: 9, weight: .regular)

            let paragraphLeft = NSMutableParagraphStyle()
            paragraphLeft.alignment = .left

            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            ("Список принимаемых лекарств" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
            y += titleFont.lineHeight + 8

            let subtitleAttrs: [NSAttributedString.Key: Any] = [.font: subtitleFont, .paragraphStyle: paragraphLeft]
            let formattedNow = DateFormatter.russianDateTime.string(from: Date())
            ("Сформировано: \(formattedNow)" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += subtitleFont.lineHeight + 4
            ("Пациент: \(patientName)" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: subtitleAttrs)
            y += subtitleFont.lineHeight + 20

            let tableWidth = pageRect.width - margin * 2
            let col1Width = tableWidth * 0.45
            let col2Width = tableWidth * 0.25
            let col3Width = tableWidth * 0.30
            let rowHeight: CGFloat = 22

            let headerAttrs: [NSAttributedString.Key: Any] = [.font: tableHeaderFont, .paragraphStyle: paragraphLeft]
            let headerY = y + (rowHeight - tableHeaderFont.lineHeight) / 2
            ("Препарат" as NSString).draw(in: CGRect(x: margin + 4, y: headerY, width: col1Width - 8, height: tableHeaderFont.lineHeight), withAttributes: headerAttrs)
            ("Дозировка" as NSString).draw(in: CGRect(x: margin + col1Width + 4, y: headerY, width: col2Width - 8, height: tableHeaderFont.lineHeight), withAttributes: headerAttrs)
            ("Время приёма" as NSString).draw(in: CGRect(x: margin + col1Width + col2Width + 4, y: headerY, width: col3Width - 8, height: tableHeaderFont.lineHeight), withAttributes: headerAttrs)
            y += rowHeight

            let cellAttrs: [NSAttributedString.Key: Any] = [.font: tableCellFont, .paragraphStyle: paragraphLeft]
            let timeFormatter = DateFormatter.russianTime

            for med in meds {
                if y + rowHeight + 40 > pageRect.height {
                    context.beginPage()
                    y = 40
                }
                let cellY = y + (rowHeight - tableCellFont.lineHeight) / 2
                let dosage = med.formattedDosage.isEmpty ? "—" : med.formattedDosage
                (med.name as NSString).draw(in: CGRect(x: margin + 4, y: cellY, width: col1Width - 8, height: tableCellFont.lineHeight), withAttributes: cellAttrs)
                (dosage as NSString).draw(in: CGRect(x: margin + col1Width + 4, y: cellY, width: col2Width - 8, height: tableCellFont.lineHeight), withAttributes: cellAttrs)
                (timeFormatter.string(from: med.time) as NSString).draw(in: CGRect(x: margin + col1Width + col2Width + 4, y: cellY, width: col3Width - 8, height: tableCellFont.lineHeight), withAttributes: cellAttrs)
                y += rowHeight
            }

            y += 24
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .paragraphStyle: paragraphLeft, .foregroundColor: UIColor.secondaryLabel]
            ("Данные сформированы приложением RenalTracker" as NSString).draw(
                at: CGPoint(x: margin, y: min(y, pageRect.height - footerFont.lineHeight - 20)),
                withAttributes: footerAttrs
            )
        }

        let pdfDocument = PDFDocument(data: data)
        return pdfDocument?.dataRepresentation() ?? data
    }

    static func fileURL(from data: Data) throws -> URL {
        let datePart = DateFormatter.fileDate.string(from: Date())
        let fileName = "Medications-\(datePart).pdf"
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
