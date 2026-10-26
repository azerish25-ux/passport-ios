//
//  DocumentSpec.swift
//  PassportProof
//
//  One verified document workflow. Physical print rules and digital upload
//  rules are deliberately different products, even for the same document.
//

import Foundation
import CoreGraphics

struct ChangelogEntry: Identifiable, Sendable {
    let id: String
    let date: Date
    let note: String
}

enum DocumentWorkflow: String, Sendable {
    case printedPhoto
    case digitalPhoto

    var title: String {
        switch self {
        case .printedPhoto: return "Printed photo"
        case .digitalPhoto: return "Digital upload"
        }
    }

    var shortTitle: String {
        switch self {
        case .printedPhoto: return "PRINT"
        case .digitalPhoto: return "DIGITAL"
        }
    }
}

enum HeadMeasurement: String, Sendable {
    /// Passport FAM: anatomical head, excluding the applicant's hair.
    case skull
    /// Visa/DV composition template: top of the head including hair.
    case includingHair

    var description: String {
        switch self {
        case .skull: return "chin to estimated skull crown"
        case .includingHair: return "chin to top of the head, including hair"
        }
    }
}

struct DocumentSpec: Identifiable, Sendable {
    let id: String
    let country: String
    let countryCode: String
    let documentName: String
    let workflow: DocumentWorkflow

    let widthMM: Double
    let heightMM: Double
    let widthPixels: Int
    let heightPixels: Int

    /// Chin to the workflow's head reference, in millimetres. Digital workflow
    /// values are the published fractions expressed on a 50.8 mm square.
    let headHeightMM: ClosedRange<Double>
    let headMeasurement: HeadMeasurement
    /// Head height ÷ image height, as a 0…1 fraction, where published.
    let headHeightShare: ClosedRange<Double>?
    /// Eye line measured up from the bottom edge, where published.
    let eyeLineFromBottomMM: ClosedRange<Double>?

    let maximumPhotoAgeMonths: Double
    let maximumFileSizeBytes: Int?
    let backgroundDescription: String
    let expressionRequirement: String
    let glassesRequirement: String

    let sourceURL: URL
    let verifiedOn: Date
    let changelog: [ChangelogEntry]

    var displayName: String { "\(country) \(documentName)" }
    var pixelSize: CGSize { CGSize(width: widthPixels, height: heightPixels) }
    var aspectRatio: Double { widthMM / heightMM }
    var supportsPrintSheet: Bool { workflow == .printedPhoto }
    var supportsDigitalExport: Bool { workflow == .digitalPhoto }

    /// Physical size for a printed workflow. Whole inches are shown in inches
    /// because that is how the issuer states them ("2 × 2 inches"); everything
    /// else is shown in millimetres rather than a misleading decimal inch value.
    var printSizeLabel: String {
        let inchesWidth = widthMM / 25.4
        let inchesHeight = heightMM / 25.4
        func isWholeOrHalf(_ value: Double) -> Bool {
            abs(value - value.rounded()) < 0.01 || abs(value * 2 - (value * 2).rounded()) < 0.01
        }
        if isWholeOrHalf(inchesWidth), isWholeOrHalf(inchesHeight) {
            return "\(Format.compact(inchesWidth)) × \(Format.compact(inchesHeight)) in"
        }
        return Format.sizeMM(width: widthMM, height: heightMM)
    }

    /// The one-line output description used by library cards and detail views.
    var outputSummaryLabel: String {
        supportsPrintSheet ? printSizeLabel : Format.sizePixels(width: widthPixels, height: heightPixels)
    }

    /// Physical size at the export pixel density. Used in print footers and the
    /// requirements disclosure, where both units are useful.
    var millimetreLabel: String {
        Format.sizeMM(width: widthMM, height: heightMM)
    }
}
