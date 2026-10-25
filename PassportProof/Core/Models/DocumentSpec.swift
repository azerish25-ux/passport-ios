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
}
