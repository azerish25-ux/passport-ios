//
//  ManualFraming.swift
//  PassportProof
//
//  Measurements of guides placed and confirmed by the user. These values are
//  never FaceGeometry, detected landmarks, or proof of issuer acceptance.
//

import Foundation

struct ManualFramingGuides: Equatable, Sendable {
    /// Coordinates in the accepted photo, normalised from its top-left corner.
    /// topY means the anatomical skull crown, excluding hair, for a passport;
    /// it means the top of the head including hair for visa and DV workflows.
    /// chinY is the anatomical chin, not the bottom of a beard.
    var topY: Double
    var chinY: Double
    var eyeY: Double
    var centerX: Double

    /// An illustrative starting drawing only. It contains no observation of
    /// the user's photo and cannot supply any of the required confirmations.
    static func suggested(for spec: DocumentSpec) -> ManualFramingGuides {
        let headShare: Double
        if let band = spec.headHeightShare {
            headShare = (band.lowerBound + band.upperBound) / 2
        } else {
            headShare = (spec.headHeightMM.lowerBound + spec.headHeightMM.upperBound) / 2 / spec.heightMM
        }
        let eyeY: Double
        if let band = spec.eyeLineFromBottomMM {
            eyeY = 1 - (band.lowerBound + band.upperBound) / 2 / spec.heightMM
        } else {
            eyeY = 0.40
        }
        // This drawing relationship is an app-selected starting position,
        // not an anatomical measurement or a published photo requirement.
        let topY = eyeY - headShare * 0.40
        return ManualFramingGuides(topY: topY, chinY: topY + headShare, eyeY: eyeY, centerX: 0.5)
    }
}

struct ManualFramingAssessment: Equatable, Sendable {
    let isValid: Bool
    let issues: [String]
    /// Values are calculated directly from the supplied guides, without
    /// clamping. Invalid input may produce nonfinite metrics; a view must
    /// check isFinite before formatting or converting a metric.
    let headHeightMM: Double
    let headHeightShare: Double
    let eyeLineFromBottomMM: Double
    let horizontalOffsetMM: Double

    init(guides: ManualFramingGuides, spec: DocumentSpec) {
        let share = guides.chinY - guides.topY
        let headMM = share * spec.heightMM
        let eyeMM = (1 - guides.eyeY) * spec.heightMM
        let offsetMM = abs(guides.centerX - 0.5) * spec.widthMM
        headHeightShare = share
        headHeightMM = headMM
        eyeLineFromBottomMM = eyeMM
        horizontalOffsetMM = offsetMM

        var problems: [String] = []
        let coordinates = [
            ("Top-of-head", guides.topY), ("Chin", guides.chinY),
            ("Eye-line", guides.eyeY), ("Face-centre", guides.centerX)
        ]
        for (name, value) in coordinates {
            if !value.isFinite || !(0...1).contains(value) {
                problems.append("\(name) guide must be a finite position inside the photo.")
            }
        }
        guard problems.isEmpty else {
            issues = problems
            isValid = false
            return
        }
        guard spec.widthMM.isFinite, spec.widthMM > 0,
              spec.heightMM.isFinite, spec.heightMM > 0 else {
            issues = ["This document has no usable photo dimensions for manual measurement."]
            isValid = false
            return
        }

        if !(guides.topY < guides.eyeY && guides.eyeY < guides.chinY) {
            problems.append("Place the top-of-head guide above the eyes and the chin guide below the eyes.")
        }
        let reference: String
        switch spec.headMeasurement {
        case .skull: reference = "chin to skull crown, excluding hair"
        case .includingHair: reference = "chin to top of the head, including hair"
        }

        // A published percentage is the authoritative digital criterion.
        // Converted millimetres remain a display value, not a second rule.
        if let band = spec.headHeightShare {
            if !Self.contains(share, in: band) {
                let range = MeasurementFormat.range(band.lowerBound * 100, band.upperBound * 100, unit: "%")
                problems.append("The selected \(reference) must cover \(range) of the photo height for this document.")
            }
        } else if !Self.contains(headMM, in: spec.headHeightMM) {
            let range = MeasurementFormat.range(spec.headHeightMM.lowerBound, spec.headHeightMM.upperBound, unit: "mm")
            problems.append("The selected \(reference) must measure \(range) on the final photo for this document.")
        }

        if let band = spec.eyeLineFromBottomMM, !Self.contains(eyeMM, in: band) {
            let range = MeasurementFormat.range(band.lowerBound, band.upperBound, unit: "mm")
            problems.append("The eye-line guide must be \(range) above the bottom edge for this document.")
        }
        let centringLimit = ValidationEngine.centringToleranceMM
        if !Self.contains(offsetMM, in: 0...centringLimit) {
            problems.append("Centre the face within the app's \(MeasurementFormat.number(centringLimit)) mm guide. This tolerance is an app setting, not a published issuer measurement.")
        }

        issues = problems
        isValid = problems.isEmpty
    }

    private static func contains(_ value: Double, in band: ClosedRange<Double>) -> Bool {
        guard value.isFinite, band.lowerBound.isFinite, band.upperBound.isFinite else { return false }
        // Closed endpoints must survive normalised-coordinate arithmetic:
        // for example, 1 - 0.31 and 0.69 can differ by one representable step.
        // Four ULPs account only for that roundoff, not photographic uncertainty
        // or any meaningful extension of a published range. Values are unchanged.
        let roundoff = max(value.ulp, max(band.lowerBound.ulp, band.upperBound.ulp)) * 4
        return value >= band.lowerBound - roundoff && value <= band.upperBound + roundoff
    }
}

struct ManualFramingReview: Equatable, Sendable {
    var guidesConfirmed = false
    var singleFaceAndPoseConfirmed = false
    var backgroundAndLightingConfirmed = false
    var limitationsAccepted = false

    static let pending = ManualFramingReview()

    var allConfirmed: Bool {
        guidesConfirmed && singleFaceAndPoseConfirmed && backgroundAndLightingConfirmed && limitationsAccepted
    }
}

/// Immutable snapshot for one accepted crop and document. PhotoSession checks
/// the identifiers and invalidates this record when either context changes.
struct ManualFramingRecord: Equatable, Sendable {
    let guides: ManualFramingGuides
    let review: ManualFramingReview
    let documentID: String
    let revision: UUID
}
