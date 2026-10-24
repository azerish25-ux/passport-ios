//
//  DocumentSpec.swift
//  PassportProof
//
//  One encoded document. Everything a rule needs, plus the provenance the
//  library screen is required to show.
//

import Foundation
import CoreGraphics

// MARK: - Changelog

struct ChangelogEntry: Identifiable, Sendable {
    let id: String
    let date: Date
    let note: String
}

// MARK: - Document

struct DocumentSpec: Identifiable, Sendable {
    let id: String
    let country: String
    let countryCode: String
    let documentName: String

    let widthMM: Double
    let heightMM: Double
    let widthPixels: Int
    let heightPixels: Int

    /// Chin to top of skull, in millimetres. Never the 22 mm metric clause.
    let headHeightMM: ClosedRange<Double>
    /// Head height ÷ image height, as a 0…1 fraction, where the document states one.
    let headHeightShare: ClosedRange<Double>?
    /// Eye line measured up from the bottom edge, in millimetres, where stated.
    let eyeLineFromBottomMM: ClosedRange<Double>?

    let backgroundDescription: String
    let sourceURL: URL
    let verifiedOn: Date
    let changelog: [ChangelogEntry]
    let isPrototypeData: Bool

    var displayName: String { "\(country) — \(documentName)" }

    var pixelSize: CGSize { CGSize(width: widthPixels, height: heightPixels) }
}
