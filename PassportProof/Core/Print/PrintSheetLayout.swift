//
//  PrintSheetLayout.swift
//  PassportProof
//
//  Page boxes are in points at 72 per inch, so the page box *is* the physical
//  geometry. A PDF carries a MediaBox; a print driver applies its own default
//  scaling, and "fit to page" is a common default. Hence the instruction
//  printed on every sheet.
//

import Foundation
import UIKit
import CoreGraphics

// MARK: - Layout

enum PrintSheetLayout: String, CaseIterable, Identifiable, Sendable {
    case fourBySix
    case fiveBySeven
    case letter12
    case letter20

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fourBySix: return "4 × 6 in"
        case .fiveBySeven: return "5 × 7 in"
        case .letter12: return "Letter — 12-up"
        case .letter20: return "Letter — 20-up"
        }
    }

    /// 72 points per inch.
    var pageSizePoints: CGSize {
        switch self {
        case .fourBySix: return CGSize(width: 288, height: 432)      // 4 × 6 in
        case .fiveBySeven: return CGSize(width: 360, height: 504)    // 5 × 7 in
        case .letter12, .letter20: return CGSize(width: 612, height: 792) // 8.5 × 11 in
        }
    }

    /// Gutter allowance around each cell, in points. Only the 12-up sheet has a
    /// real gutter; its 0.25 in row gutter is split either side of the cut.
    var cellInsetPoints: CGFloat {
        switch self {
        case .fourBySix, .fiveBySeven, .letter20: return 0
        case .letter12: return 9
        }
    }

    var supportsCutMarks: Bool {
        switch self {
        case .letter12: return true
        case .fourBySix, .fiveBySeven, .letter20: return false
        }
    }

    // MARK: Internal geometry

    /// Horizontal margin on each side, in points.
    var sideMarginPoints: CGFloat {
        switch self {
        case .fourBySix: return 0            // derived: zero side margin, borderless only
        case .fiveBySeven: return 36         // stated: 0.5 in
        case .letter12: return 90            // stated: 1.25 in
        case .letter20: return 18            // stated: 0.25 in
        }
    }

    /// Vertical margin top and bottom, in points.
    var verticalMarginPoints: CGFloat {
        switch self {
        case .fourBySix: return 72           // derived: 1 in
        case .fiveBySeven: return 36         // stated: 0.5 in
        case .letter12: return 81            // derived: 1.125 in
        case .letter20: return 36            // derived: 0.5 in
        }
    }

    var columnGutterPoints: CGFloat {
        // 12-up does not close on Letter with a column gutter: the only
        // self-consistent reading is 1.25 in sides and zero between columns.
        return 0
    }

    var rowGutterPoints: CGFloat {
        switch self {
        case .letter12: return 18            // stated: 0.25 in
        case .fourBySix, .fiveBySeven, .letter20: return 0
        }
    }
}

// MARK: - Plan

/// How many true-size photos fit on one page.
///
/// The grid is derived from the document's physical size instead of being
/// hardcoded per paper. Hardcoded counts only ever described a 2 × 2 in US
/// passport photo, so a 35 × 45 mm or 50 × 70 mm document would either waste
/// half the page or, worse, be scaled down to satisfy a pre-set column count.
struct PrintPlan: Equatable, Sendable {
    let layout: PrintSheetLayout
    let columns: Int
    let rows: Int
    /// One photo at true printed size, in points at 72 dpi.
    let photoSize: CGSize

    var count: Int { columns * rows }

    init(layout: PrintSheetLayout, spec: DocumentSpec) {
        self.layout = layout
        let page = layout.pageSizePoints
        let photoWidth = max(CGFloat(spec.widthMM) * 72.0 / 25.4, 1)
        let photoHeight = max(CGFloat(spec.heightMM) * 72.0 / 25.4, 1)
        photoSize = CGSize(width: photoWidth, height: photoHeight)
        let availableWidth = page.width - layout.sideMarginPoints * 2
        let availableHeight = page.height - layout.verticalMarginPoints * 2
        let columnGutter = layout.columnGutterPoints
        let rowGutter = layout.rowGutterPoints

        // Floor division on the pitch, so the last column or row is only counted
        // when a full photo plus its gutter actually fits. The epsilon absorbs
        // binary rounding: 50.8 mm is exactly two inches on paper, but the
        // division must not floor 2.0000000001 down to 1 and halve a sheet.
        let epsilon = 1e-9
        columns = max(1, Int((((availableWidth + columnGutter) / (photoWidth + columnGutter)) + epsilon).rounded(.down)))
        rows = max(1, Int((((availableHeight + rowGutter) / (photoHeight + rowGutter)) + epsilon).rounded(.down)))
    }
}

// MARK: - Renderer

struct PrintSheetRenderer {

    private static let instruction = "PRINT AT 100% — DO NOT SCALE"

    // MARK: Photo sheet

    static func pdfData(photo: CGImage, layout: PrintSheetLayout, spec: DocumentSpec) -> Data? {
        let page = layout.pageSizePoints
        let sourceAspect = Double(photo.width) / Double(max(photo.height, 1))
        guard spec.supportsPrintSheet,
              abs(sourceAspect - spec.aspectRatio) < 0.02,
              page.width > 0,
              page.height > 0 else { return nil }

        let plan = PrintPlan(layout: layout, spec: spec)
        let metrics = SheetMetrics(layout: layout, plan: plan)
        guard metrics.cellSize.width > 1, metrics.cellSize.height > 1 else { return nil }

        let bounds = CGRect(origin: .zero, size: page)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)
        let image = UIImage(cgImage: photo)

        return renderer.pdfData { context in
            context.beginPage()
            let cg = context.cgContext

            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(bounds)

            for row in 0..<plan.rows {
                for column in 0..<plan.columns {
                    let cell = metrics.cellRect(row: row, column: column)

                    // `UIImage.draw(in:)` honours the UIKit flipped coordinate
                    // system that UIGraphicsPDFRenderer establishes. Drawing
                    // the CGImage directly here would render it upside down.
                    image.draw(in: cell)

                    cg.setStrokeColor(UIColor(white: 0.78, alpha: 1).cgColor)
                    cg.setLineWidth(0.5)
                    cg.stroke(cell)
                }
            }

            if layout.supportsCutMarks {
                drawCutMarks(in: cg, metrics: metrics, layout: layout, plan: plan)
            }

            drawFooter(metrics: metrics, layout: layout, spec: spec, bounds: bounds)
        }
    }

    // MARK: Calibration sheet

    /// One page, printed and measured with a ruler before the unlock is spent.
    /// Printing it costs nothing.
    static func calibrationPDFData(layout: PrintSheetLayout, spec: DocumentSpec? = nil) -> Data? {
        let page = layout.pageSizePoints
        guard page.width > 0, page.height > 0 else { return nil }

        let bounds = CGRect(origin: .zero, size: page)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds)

        return renderer.pdfData { context in
            context.beginPage()
            let cg = context.cgContext

            cg.setFillColor(UIColor.white.cgColor)
            cg.fill(bounds)

            let margin: CGFloat = 24
            let contentWidth = page.width - margin * 2
            let titleFont = UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            let bodyFont = UIFont.monospacedSystemFont(ofSize: 8, weight: .regular)
            let labelFont = UIFont.monospacedSystemFont(ofSize: 7, weight: .regular)

            drawCentred("CALIBRATION SHEET", in: CGRect(x: margin, y: margin, width: contentWidth, height: 16), font: titleFont)
            drawCentred(layout.title + " · " + sizeDescription(page), in: CGRect(x: margin, y: margin + 18, width: contentWidth, height: 12), font: bodyFont)

            // Ruler. Shortened to fit the narrowest page rather than clipped.
            let maximumRulerMM = 100.0
            let availableMM = Double(contentWidth) * 25.4 / 72.0
            let rulerMM = max(10.0, (min(maximumRulerMM, availableMM) / 10.0).rounded(.down) * 10.0)
            let rulerLength = CGFloat(rulerMM) * 72.0 / 25.4
            let rulerOrigin = CGPoint(x: (page.width - rulerLength) / 2, y: margin + 56)

            cg.setStrokeColor(UIColor.black.cgColor)
            cg.setLineWidth(0.75)
            cg.move(to: rulerOrigin)
            cg.addLine(to: CGPoint(x: rulerOrigin.x + rulerLength, y: rulerOrigin.y))
            cg.strokePath()

            var tick = 0.0
            while tick <= rulerMM + 0.001 {
                let x = rulerOrigin.x + CGFloat(tick) * 72.0 / 25.4
                let isMajor = tick.truncatingRemainder(dividingBy: 10) < 0.001
                let height: CGFloat = isMajor ? 9 : 5
                cg.setLineWidth(isMajor ? 0.75 : 0.4)
                cg.move(to: CGPoint(x: x, y: rulerOrigin.y))
                cg.addLine(to: CGPoint(x: x, y: rulerOrigin.y + height))
                cg.strokePath()
                if isMajor {
                    let label = String(format: "%.0f", tick)
                    drawCentred(label, in: CGRect(x: x - 14, y: rulerOrigin.y + 11, width: 28, height: 10), font: labelFont)
                }
                tick += 5
            }

            drawCentred(
                String(format: "This line must measure %.0f mm. If it does not, the printer is scaling the page.", rulerMM),
                in: CGRect(x: margin, y: rulerOrigin.y + 26, width: contentWidth, height: 12),
                font: bodyFont
            )

            // One cell at the document's real size, so the check measures the
            // geometry that will actually be printed rather than a fixed 2 in
            // square that only applied to the US passport sheet.
            let squareSide = CGFloat(spec?.widthMM ?? 50.8) * 72.0 / 25.4
            let squareHeight = CGFloat(spec?.heightMM ?? 50.8) * 72.0 / 25.4
            let squareRect = CGRect(
                x: (page.width - squareSide) / 2,
                y: rulerOrigin.y + 48,
                width: squareSide,
                height: squareHeight
            )
            cg.setLineWidth(0.75)
            cg.stroke(squareRect)
            let cellLabel = String(format: "%.3f × %.3f in / %.1f × %.1f mm",
                                   squareSide / 72, squareHeight / 72,
                                   squareSide * 25.4 / 72, squareHeight * 25.4 / 72)
            drawCentred(cellLabel, in: CGRect(x: squareRect.minX, y: squareRect.maxY + 6, width: squareSide, height: 10), font: labelFont)

            drawCentred(instruction, in: CGRect(x: margin, y: page.height - margin - 14, width: contentWidth, height: 14), font: titleFont)
        }
    }

    // MARK: - Drawing helpers

    private static func drawCutMarks(in cg: CGContext, metrics: SheetMetrics, layout: PrintSheetLayout, plan: PrintPlan) {
        let length: CGFloat = 7
        let inset: CGFloat = 3
        let minimumGutter: CGFloat = 10

        cg.setStrokeColor(UIColor.black.cgColor)
        cg.setLineWidth(0.5)

        for row in 0..<plan.rows {
            for column in 0..<plan.columns {
                let cell = metrics.cellRect(row: row, column: column)

                let spaceLeft = column == 0 ? cell.minX : layout.columnGutterPoints
                let spaceRight = column == plan.columns - 1
                    ? metrics.pageSize.width - cell.maxX
                    : layout.columnGutterPoints
                let spaceUp = row == 0 ? cell.minY : layout.rowGutterPoints
                let spaceDown = row == plan.rows - 1
                    ? metrics.pageSize.height - cell.maxY
                    : layout.rowGutterPoints

                let corners: [(x: CGFloat, y: CGFloat, horizontal: CGFloat, vertical: CGFloat)] = [
                    (cell.minX, cell.minY, -1, -1),
                    (cell.maxX, cell.minY, 1, -1),
                    (cell.minX, cell.maxY, -1, 1),
                    (cell.maxX, cell.maxY, 1, 1)
                ]

                for corner in corners {
                    let horizontalSpace = corner.horizontal < 0 ? spaceLeft : spaceRight
                    let verticalSpace = corner.vertical < 0 ? spaceUp : spaceDown

                    if horizontalSpace >= minimumGutter {
                        let start = CGPoint(x: corner.x + corner.horizontal * inset, y: corner.y)
                        let end = CGPoint(x: start.x + corner.horizontal * length, y: corner.y)
                        cg.move(to: start)
                        cg.addLine(to: end)
                        cg.strokePath()
                    }
                    if verticalSpace >= minimumGutter {
                        let start = CGPoint(x: corner.x, y: corner.y + corner.vertical * inset)
                        let end = CGPoint(x: corner.x, y: start.y + corner.vertical * length)
                        cg.move(to: start)
                        cg.addLine(to: end)
                        cg.strokePath()
                    }
                }
            }
        }
    }

    private static func drawFooter(
        metrics: SheetMetrics,
        layout: PrintSheetLayout,
        spec: DocumentSpec,
        bounds: CGRect
    ) {
        let footerTop = metrics.gridRect.maxY
        let footer = CGRect(
            x: metrics.sideMargin,
            y: footerTop,
            width: bounds.width - metrics.sideMargin * 2,
            height: max(bounds.height - footerTop, 20)
        )

        let instructionFont = UIFont.monospacedSystemFont(ofSize: 8, weight: .bold)
        let metaFont = UIFont.monospacedSystemFont(ofSize: 7, weight: .regular)

        drawCentred(
            instruction,
            in: CGRect(x: footer.minX, y: footer.minY + 5, width: footer.width, height: 11),
            font: instructionFont
        )

        let meta = spec.displayName
            + " · " + "\(spec.widthPixels) × \(spec.heightPixels) px"
            + " · " + "\(spec.widthMM) × \(spec.heightMM) mm"
            + " · " + dateStamp()
            + " · " + layout.title

        drawCentred(
            meta,
            in: CGRect(x: footer.minX, y: footer.minY + 18, width: footer.width, height: 10),
            font: metaFont
        )
    }

    private static func drawCentred(_ string: String, in rect: CGRect, font: UIFont) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph
        ]
        NSAttributedString(string: string, attributes: attributes).draw(in: rect)
    }

    private static func sizeDescription(_ size: CGSize) -> String {
        String(format: "%.2f × %.2f in", size.width / 72.0, size.height / 72.0)
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Sheet metrics

/// Where the cells actually land. Cell size comes from the document, then is
/// clamped to what the page can hold — a 51 mm document resolves to 144.57 pt,
/// which does not fit two-up on a 288 pt page, so it clamps to the exact 2 in
/// cell the layout is built around.
private struct SheetMetrics {
    let pageSize: CGSize
    let cellSize: CGSize
    let gridRect: CGRect
    let sideMargin: CGFloat
    let columnGutter: CGFloat
    let rowGutter: CGFloat

    init(layout: PrintSheetLayout, plan: PrintPlan) {
        let page = layout.pageSizePoints
        pageSize = page
        sideMargin = layout.sideMarginPoints
        columnGutter = layout.columnGutterPoints
        rowGutter = layout.rowGutterPoints

        let columns = CGFloat(plan.columns)
        let rows = CGFloat(plan.rows)
        let availableWidth = page.width - layout.sideMarginPoints * 2 - columnGutter * (columns - 1)
        let availableHeight = page.height - layout.verticalMarginPoints * 2 - rowGutter * (rows - 1)

        // The cell is always the document's true physical size. `PrintPlan`
        // floored the grid so a full photo fits; the available-space division
        // is only a guard and must never grow the cell to fill spare paper.
        cellSize = CGSize(
            width: min(plan.photoSize.width, availableWidth / columns),
            height: min(plan.photoSize.height, availableHeight / rows)
        )

        let gridWidth = columns * cellSize.width + columnGutter * (columns - 1)
        let gridHeight = rows * cellSize.height + rowGutter * (rows - 1)

        gridRect = CGRect(
            x: (page.width - gridWidth) / 2,
            y: (page.height - gridHeight) / 2,
            width: gridWidth,
            height: gridHeight
        )
    }

    func cellRect(row: Int, column: Int) -> CGRect {
        CGRect(
            x: gridRect.minX + CGFloat(column) * (cellSize.width + columnGutter),
            y: gridRect.minY + CGFloat(row) * (cellSize.height + rowGutter),
            width: cellSize.width,
            height: cellSize.height
        )
    }
}
