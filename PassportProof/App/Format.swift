//
//  Format.swift
//  PassportProof
//
//  One place for the numbers that appear as text. Fixed locale, fixed time
//  zone, no thousands separators, en dash for ranges (DesignSystem §2).
//

import Foundation
import CoreGraphics

enum Format {

    // MARK: Dates

    private static let isoDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// `2026-03-14`. Used for verification dates and changelog entries.
    static func day(_ date: Date) -> String {
        isoDay.string(from: date)
    }

    // MARK: Numbers

    /// One decimal place, always. `25.4`.
    static func decimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// Drops a trailing `.0`. `51`, `25.4`.
    static func compact(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    /// `25.4–34.9 mm`.
    static func range(_ lower: Double, _ upper: Double, unit: String) -> String {
        "\(decimal(lower))–\(decimal(upper)) \(unit)"
    }

    /// `51 × 51 mm`.
    static func sizeMM(width: Double, height: Double) -> String {
        "\(compact(width)) × \(compact(height)) mm"
    }

    /// `600 × 600 px`.
    static func sizePixels(width: Int, height: Int) -> String {
        "\(width) × \(height) px"
    }

    /// `4 × 6 in`, from a page size in points at 72 dpi.
    static func inches(_ points: CGFloat) -> String {
        compact(Double(points) / 72.0)
    }

    /// `8.5 × 11 in`, from a page size in points at 72 dpi.
    static func pageInches(_ size: CGSize) -> String {
        "\(inches(size.width)) × \(inches(size.height)) in"
    }
}

// MARK: - Provenance wording

extension Provenance {

    /// The label shown to the user. App-selected thresholds remain explicit
    /// and are never presented as issuer-published tolerances.
    var uiLabel: String {
        switch self {
        case .source:
            return "issuer rule"
        case .derived:
            return "derived from issuer rule"
        case .prototypeDefault:
            return "app threshold — not issuer specified"
        }
    }
}

extension FindingStatus {

    var uiLabel: String {
        switch self {
        case .pass:
            return "Pass"
        case .fail:
            return "Fail"
        case .cannotVerify:
            return "Review"
        }
    }
}
