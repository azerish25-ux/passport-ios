//
//  ValidationEngine.swift
//  PassportProof
//
//  The product. Eleven rules, three states, fixed order.
//
//  Order: headHeight, headHeightShare, eyeLine, centring,
//  backgroundUniformity, shadow, expression, glasses, resolution, photoAge,
//  noManipulation.
//

import Foundation
import CoreGraphics

// MARK: - Result

struct PhotoAnalysis: Sendable {
    let findings: [Finding]
    let geometry: FaceGeometry?
    let background: BackgroundReport?
    let overall: FindingStatus

    var failures: [Finding] { findings.filter { $0.status == .fail } }
}

// MARK: - Engine

enum ValidationEngine {

    // MARK: Thresholds (prototype defaults — labelled as such in the UI)

    /// Divergence between the silhouette envelope and the inferred crown, as a
    /// fraction of measured head height. Beyond this the head height is not
    /// trustworthy in either direction.
    static let crownDivergenceLimit = 0.06

    /// Maximum horizontal offset of the face centre from the image centre.
    static let centringToleranceMM = 3.0

    /// Maximum luminance delta across the face box.
    static let shadowDeltaLimit = 0.22

    /// Minimum short-side source resolution.
    static let minimumSourcePixels = 1200

    /// Maximum age of the photograph.
    static let maximumPhotoAgeMonths = 6.0

    // MARK: - Analysis

    static func analyze(image: CGImage, spec: DocumentSpec) -> PhotoAnalysis {
        analyze(image: image, spec: spec, captureDate: nil)
    }

    /// Variant that accepts an EXIF capture date. `CGImage` does not carry
    /// metadata, so callers that have the `CGImageSource` or a `PHAsset` should
    /// pass the date through here; without it the photo-age rule reports
    /// `cannotVerify` rather than guessing.
    static func analyze(image: CGImage, spec: DocumentSpec, captureDate: Date?) -> PhotoAnalysis {
        let pixelSize = CGSize(width: image.width, height: image.height)
        let geometry = FaceAnalyzer.geometry(of: image)

        var background: BackgroundReport?
        if let geometry {
            background = BackgroundAnalyzer.analyze(image, faceBox: geometry.faceBox)
        }

        let sample = SampledImage(image: image)
        var measuredShadowDelta: Double?
        var suspectedGlare = false
        if let sample, let geometry {
            measuredShadowDelta = shadowDelta(in: sample, faceBox: geometry.faceBox)
            suspectedGlare = glareSuspected(in: sample, geometry: geometry)
        }

        let allFindings = findings(
            geometry: geometry,
            background: background,
            spec: spec,
            imagePixelSize: pixelSize,
            captureDate: captureDate,
            shadowDelta: measuredShadowDelta,
            glareSuspected: suspectedGlare
        )

        return PhotoAnalysis(
            findings: allFindings,
            geometry: geometry,
            background: background,
            overall: overall(for: allFindings)
        )
    }

    /// Contract signature. Shadow and glare signals are unavailable here, so
    /// those two rules report honestly rather than inventing a value.
    static func findings(
        geometry: FaceGeometry?,
        background: BackgroundReport?,
        spec: DocumentSpec,
        imagePixelSize: CGSize,
        captureDate: Date?
    ) -> [Finding] {
        findings(
            geometry: geometry,
            background: background,
            spec: spec,
            imagePixelSize: imagePixelSize,
            captureDate: captureDate,
            shadowDelta: nil,
            glareSuspected: false
        )
    }

    // MARK: - Aggregation

    static func overall(for findings: [Finding]) -> FindingStatus {
        if findings.contains(where: { $0.status == .fail }) { return .fail }
        if findings.contains(where: { $0.status == .cannotVerify }) { return .cannotVerify }
        return .pass
    }

    // MARK: - The rules

    private static func findings(
        geometry: FaceGeometry?,
        background: BackgroundReport?,
        spec: DocumentSpec,
        imagePixelSize: CGSize,
        captureDate: Date?,
        shadowDelta: Double?,
        glareSuspected: Bool
    ) -> [Finding] {
        [
            headHeight(geometry: geometry, spec: spec),
            headHeightShare(geometry: geometry, spec: spec),
            eyeLine(geometry: geometry, spec: spec),
            centring(geometry: geometry, spec: spec),
            backgroundUniformity(background: background),
            shadow(delta: shadowDelta),
            expression(),
            glasses(glareSuspected: glareSuspected),
            resolution(imagePixelSize: imagePixelSize),
            photoAge(captureDate: captureDate),
            noManipulation()
        ]
    }

    // MARK: R1 / R2 — head height

    private static func headHeight(geometry: FaceGeometry?, spec: DocumentSpec) -> Finding {
        let range = spec.headHeightMM
        let rangeText = MeasurementFormat.range(range.lowerBound, range.upperBound, unit: "mm")

        guard let geometry else {
            return Finding(
                id: .headHeight,
                title: "Head height",
                status: .cannotVerify,
                detail: "No face was detected, so chin-to-crown cannot be measured. Face the camera directly, fill the frame with your head and shoulders, and try again.",
                measurement: nil,
                provenance: .source
            )
        }

        let measuredMM = geometry.headHeight * spec.heightMM
        let measurement = MeasurementFormat.millimetres(
            value: measuredMM,
            lowerBound: range.lowerBound,
            upperBound: range.upperBound
        )

        // Two estimators, one answer. If they disagree, neither is trustworthy.
        if geometry.crownDivergence > crownDivergenceLimit {
            let percent = Int((geometry.crownDivergence * 100).rounded())
            return Finding(
                id: .headHeight,
                title: "Head height",
                status: .cannotVerify,
                detail: "The top of the silhouette and the chin-to-eye estimate disagree by \(percent)% of head height. Hair volume, an updo, a head covering or a wig can put the outline well above the crown, so this measurement cannot be trusted in either direction. A reviewer can measure the original.",
                measurement: measurement,
                provenance: .source
            )
        }

        let formatted = MeasurementFormat.number(measuredMM)
        if measuredMM < range.lowerBound {
            return Finding(
                id: .headHeight,
                title: "Head height",
                status: .fail,
                detail: "Chin to crown measures \(formatted) mm. \(spec.documentName) requires \(rangeText). Move closer, or crop tighter, so the head fills more of the frame.",
                measurement: measurement,
                provenance: .source
            )
        }
        if measuredMM > range.upperBound {
            return Finding(
                id: .headHeight,
                title: "Head height",
                status: .fail,
                detail: "Chin to crown measures \(formatted) mm. \(spec.documentName) requires \(rangeText). Move back, or crop looser, so the head fills less of the frame.",
                measurement: measurement,
                provenance: .source
            )
        }
        return Finding(
            id: .headHeight,
            title: "Head height",
            status: .pass,
            detail: "Chin to crown measures \(formatted) mm, inside the required \(rangeText).",
            measurement: measurement,
            provenance: .source
        )
    }

    // MARK: R3 — head height as a share of the image

    private static func headHeightShare(geometry: FaceGeometry?, spec: DocumentSpec) -> Finding {
        guard let share = spec.headHeightShare else {
            return Finding(
                id: .headHeightShare,
                title: "Head height share",
                status: .cannotVerify,
                detail: "\(spec.documentName) does not publish head height as a proportion of the image, so there is nothing to check here.",
                measurement: nil,
                provenance: .source
            )
        }

        let rangeText = MeasurementFormat.range(share.lowerBound * 100, share.upperBound * 100, unit: "%")

        guard let geometry else {
            return Finding(
                id: .headHeightShare,
                title: "Head height share",
                status: .cannotVerify,
                detail: "No face was detected, so the head's share of the frame cannot be measured.",
                measurement: nil,
                provenance: .source
            )
        }

        // `headHeight` is already normalised against image height, which is
        // exactly the proportion the document states.
        let measured = geometry.headHeight
        let measurement = Measurement(
            value: measured * 100,
            unit: "%",
            lowerBound: share.lowerBound * 100,
            upperBound: share.upperBound * 100,
            displayValue: MeasurementFormat.percent(measured * 100),
            displayRange: rangeText
        )

        if measured < share.lowerBound {
            return Finding(
                id: .headHeightShare,
                title: "Head height share",
                status: .fail,
                detail: "The head fills \(MeasurementFormat.percent(measured * 100)) of the frame height. \(spec.documentName) requires \(rangeText). Crop tighter.",
                measurement: measurement,
                provenance: .source
            )
        }
        if measured > share.upperBound {
            return Finding(
                id: .headHeightShare,
                title: "Head height share",
                status: .fail,
                detail: "The head fills \(MeasurementFormat.percent(measured * 100)) of the frame height. \(spec.documentName) requires \(rangeText). Crop looser.",
                measurement: measurement,
                provenance: .source
            )
        }
        return Finding(
            id: .headHeightShare,
            title: "Head height share",
            status: .pass,
            detail: "The head fills \(MeasurementFormat.percent(measured * 100)) of the frame height, inside the required \(rangeText).",
            measurement: measurement,
            provenance: .source
        )
    }

    // MARK: R8 — eye line

    private static func eyeLine(geometry: FaceGeometry?, spec: DocumentSpec) -> Finding {
        guard let range = spec.eyeLineFromBottomMM else {
            return Finding(
                id: .eyeLine,
                title: "Eye line",
                status: .cannotVerify,
                detail: "\(spec.documentName) does not publish an eye-line height measured from the bottom edge.",
                measurement: nil,
                provenance: .source
            )
        }

        let rangeText = MeasurementFormat.range(range.lowerBound, range.upperBound, unit: "mm")

        guard let geometry else {
            return Finding(
                id: .eyeLine,
                title: "Eye line",
                status: .cannotVerify,
                detail: "No eyes were detected, so the eye line cannot be located.",
                measurement: nil,
                provenance: .source
            )
        }

        // eyeY is measured from the top, so the distance from the bottom is 1 − eyeY.
        let measuredMM = (1 - geometry.eyeY) * spec.heightMM
        let measurement = MeasurementFormat.millimetres(
            value: measuredMM,
            lowerBound: range.lowerBound,
            upperBound: range.upperBound
        )

        if measuredMM < range.lowerBound {
            return Finding(
                id: .eyeLine,
                title: "Eye line",
                status: .fail,
                detail: "The eyes sit \(MeasurementFormat.number(measuredMM)) mm above the bottom edge. \(spec.documentName) requires \(rangeText). Crop more off the top.",
                measurement: measurement,
                provenance: .source
            )
        }
        if measuredMM > range.upperBound {
            return Finding(
                id: .eyeLine,
                title: "Eye line",
                status: .fail,
                detail: "The eyes sit \(MeasurementFormat.number(measuredMM)) mm above the bottom edge. \(spec.documentName) requires \(rangeText). Crop more off the bottom.",
                measurement: measurement,
                provenance: .source
            )
        }
        return Finding(
            id: .eyeLine,
            title: "Eye line",
            status: .pass,
            detail: "The eyes sit \(MeasurementFormat.number(measuredMM)) mm above the bottom edge, inside the required \(rangeText).",
            measurement: measurement,
            provenance: .source
        )
    }

    // MARK: R9 — centring

    private static func centring(geometry: FaceGeometry?, spec: DocumentSpec) -> Finding {
        let rangeText = MeasurementFormat.range(0, centringToleranceMM, unit: "mm")

        guard let geometry else {
            return Finding(
                id: .centring,
                title: "Centring",
                status: .cannotVerify,
                detail: "No face was detected, so the face centre cannot be located.",
                measurement: nil,
                provenance: .prototypeDefault
            )
        }

        let offsetMM = abs(geometry.faceCenterX - 0.5) * spec.widthMM
        let measurement = Measurement(
            value: offsetMM,
            unit: "mm",
            lowerBound: 0,
            upperBound: centringToleranceMM,
            displayValue: MeasurementFormat.millimetresValue(offsetMM),
            displayRange: rangeText
        )

        if offsetMM > centringToleranceMM {
            let side = geometry.faceCenterX < 0.5 ? "left" : "right"
            return Finding(
                id: .centring,
                title: "Centring",
                status: .fail,
                detail: "The face centre sits \(MeasurementFormat.number(offsetMM)) mm off the middle of the frame, to the \(side). The prototype tolerance is \(rangeText). Re-crop so the face is centred.",
                measurement: measurement,
                provenance: .prototypeDefault
            )
        }
        return Finding(
            id: .centring,
            title: "Centring",
            status: .pass,
            detail: "The face centre is \(MeasurementFormat.number(offsetMM)) mm from the middle of the frame, inside the prototype tolerance of \(rangeText).",
            measurement: measurement,
            provenance: .prototypeDefault
        )
    }

    // MARK: R5 / R15 — background uniformity

    private static func backgroundUniformity(background: BackgroundReport?) -> Finding {
        let sigmaLimitPercent = BackgroundAnalyzer.uniformitySigmaLimit * 100
        let rangeText = MeasurementFormat.range(0, sigmaLimitPercent, unit: "%")

        guard let background else {
            return Finding(
                id: .backgroundUniformity,
                title: "Background uniformity",
                status: .cannotVerify,
                detail: "No face was detected, so the background could not be separated from the subject.",
                measurement: nil,
                provenance: .prototypeDefault
            )
        }

        let sigmaPercent = background.uniformitySigma * 100
        let measurement = Measurement(
            value: sigmaPercent,
            unit: "%",
            lowerBound: 0,
            upperBound: sigmaLimitPercent,
            displayValue: MeasurementFormat.percent(sigmaPercent),
            displayRange: rangeText
        )

        let residualPercent = background.edgeResidualFraction * 100
        let base = "Background spread is \(MeasurementFormat.percent(sigmaPercent)) (limit \(rangeText)) with \(MeasurementFormat.percent(residualPercent)) of the ring at the head edge deviating from it. This is a threshold test on pixel values, not a perceptual judgement."

        if background.uniformitySigma > BackgroundAnalyzer.uniformitySigmaLimit {
            return Finding(
                id: .backgroundUniformity,
                title: "Background uniformity",
                status: .fail,
                detail: base + " The background is not even. Stand further from the wall, face a single light source, and avoid a wall that is lit unevenly across the frame.",
                measurement: measurement,
                provenance: .prototypeDefault
            )
        }
        if background.edgeResidualFraction > BackgroundAnalyzer.edgeResidualFractionLimit {
            return Finding(
                id: .backgroundUniformity,
                title: "Background uniformity",
                status: .fail,
                detail: base + " Something other than the plain background is showing at the edge of the head. Clear the frame behind you and keep hair clear of the outline.",
                measurement: measurement,
                provenance: .prototypeDefault
            )
        }
        return Finding(
            id: .backgroundUniformity,
            title: "Background uniformity",
            status: .pass,
            detail: base,
            measurement: measurement,
            provenance: .prototypeDefault
        )
    }

    // MARK: R10 — shadow

    private static func shadow(delta: Double?) -> Finding {
        let rangeText = MeasurementFormat.range(0, shadowDeltaLimit, unit: "")

        guard let delta else {
            return Finding(
                id: .shadow,
                title: "Shadow",
                status: .cannotVerify,
                detail: "Lighting across the face could not be measured for this input.",
                measurement: nil,
                provenance: .prototypeDefault
            )
        }

        let measurement = Measurement(
            value: delta,
            unit: "",
            lowerBound: 0,
            upperBound: shadowDeltaLimit,
            displayValue: MeasurementFormat.number(delta),
            displayRange: rangeText
        )

        if delta > shadowDeltaLimit {
            return Finding(
                id: .shadow,
                title: "Shadow",
                status: .fail,
                detail: "Luminance varies by \(MeasurementFormat.number(delta)) across the face; the prototype limit is \(MeasurementFormat.number(shadowDeltaLimit)). Turn to face the light so both sides of the face are lit evenly.",
                measurement: measurement,
                provenance: .prototypeDefault
            )
        }
        return Finding(
            id: .shadow,
            title: "Shadow",
            status: .pass,
            detail: "Luminance varies by \(MeasurementFormat.number(delta)) across the face, inside the prototype limit of \(MeasurementFormat.number(shadowDeltaLimit)).",
            measurement: measurement,
            provenance: .prototypeDefault
        )
    }

    // MARK: R11 — expression

    private static func expression() -> Finding {
        Finding(
            id: .expression,
            title: "Expression",
            status: .cannotVerify,
            detail: "Neutral expression cannot be determined on-device; a reviewer makes this call.",
            measurement: nil,
            provenance: .source
        )
    }

    // MARK: R12 — glasses

    private static func glasses(glareSuspected: Bool) -> Finding {
        if glareSuspected {
            return Finding(
                id: .glasses,
                title: "Glasses",
                status: .cannotVerify,
                detail: "Bright, near-white pixels around the eyes suggest glare on lenses. Remove the glasses if you can; if you cannot, a reviewer decides whether the eyes are visible.",
                measurement: nil,
                provenance: .source
            )
        }
        return Finding(
            id: .glasses,
            title: "Glasses",
            status: .pass,
            detail: "No glasses were positively detected. This check does not confirm that no glasses are worn, and it cannot rule out a thin rim or a reflection.",
            measurement: nil,
            provenance: .source
        )
    }

    // MARK: R6 / G9 — resolution

    private static func resolution(imagePixelSize: CGSize) -> Finding {
        let shortSide = Int(min(imagePixelSize.width, imagePixelSize.height).rounded())
        let rangeText = MeasurementFormat.range(Double(minimumSourcePixels), nil, unit: "px")
        let measurement = Measurement(
            value: Double(shortSide),
            unit: "px",
            lowerBound: Double(minimumSourcePixels),
            upperBound: nil,
            displayValue: "\(shortSide) px",
            displayRange: rangeText
        )

        if shortSide < minimumSourcePixels {
            return Finding(
                id: .resolution,
                title: "Resolution",
                status: .fail,
                detail: "The short side of the source is \(shortSide) px; \(minimumSourcePixels) px is the minimum for a 2 inch cell at 300 DPI. Capture at a larger size or use a higher-resolution original.",
                measurement: measurement,
                provenance: .prototypeDefault
            )
        }
        return Finding(
            id: .resolution,
            title: "Resolution",
            status: .pass,
            detail: "The short side of the source is \(shortSide) px, above the \(minimumSourcePixels) px minimum.",
            measurement: measurement,
            provenance: .prototypeDefault
        )
    }

    // MARK: R7 — photo age

    private static func photoAge(captureDate: Date?) -> Finding {
        let rangeText = MeasurementFormat.range(0, maximumPhotoAgeMonths, unit: "months")

        guard let captureDate else {
            return Finding(
                id: .photoAge,
                title: "Photo age",
                status: .cannotVerify,
                detail: "This image carries no capture date, so its age cannot be checked. The limit is \(MeasurementFormat.number(maximumPhotoAgeMonths)) months for visa documents.",
                measurement: nil,
                provenance: .source
            )
        }

        let months = Date().timeIntervalSince(captureDate) / (60 * 60 * 24 * 30.44)
        let measurement = Measurement(
            value: months,
            unit: "months",
            lowerBound: 0,
            upperBound: maximumPhotoAgeMonths,
            displayValue: MeasurementFormat.number(months) + " months",
            displayRange: rangeText
        )

        if months > maximumPhotoAgeMonths {
            return Finding(
                id: .photoAge,
                title: "Photo age",
                status: .fail,
                detail: "The photograph was captured \(MeasurementFormat.number(months)) months ago. The limit is \(MeasurementFormat.number(maximumPhotoAgeMonths)) months, so a newer photograph is required.",
                measurement: measurement,
                provenance: .source
            )
        }
        return Finding(
            id: .photoAge,
            title: "Photo age",
            status: .pass,
            detail: "The photograph was captured \(MeasurementFormat.number(months)) months ago, inside the \(MeasurementFormat.number(maximumPhotoAgeMonths)) month limit.",
            measurement: measurement,
            provenance: .source
        )
    }

    // MARK: R14 / R16 — no manipulation

    private static func noManipulation() -> Finding {
        Finding(
            id: .noManipulation,
            title: "No manipulation",
            status: .pass,
            detail: "This app applies a geometric crop only. It does not retouch, filter, or synthesise pixels.",
            measurement: nil,
            provenance: .source
        )
    }

    // MARK: - Pixel signals

    /// Largest deviation of any 3 × 3 cell of the face box from the box mean.
    private static func shadowDelta(in sample: SampledImage, faceBox: CGRect) -> Double? {
        let box = PixelSampling.clamp(faceBox)
        guard box.width > 0.01, box.height > 0.01 else { return nil }

        var cellMeans: [Double] = []
        let divisions = 3
        for row in 0..<divisions {
            for column in 0..<divisions {
                let rect = CGRect(
                    x: box.minX + box.width * CGFloat(column) / CGFloat(divisions),
                    y: box.minY + box.height * CGFloat(row) / CGFloat(divisions),
                    width: box.width / CGFloat(divisions),
                    height: box.height / CGFloat(divisions)
                )
                if let mean = sample.meanLuminance(inNormalizedRect: rect) {
                    cellMeans.append(mean)
                }
            }
        }
        guard !cellMeans.isEmpty else { return nil }
        let overallMean = cellMeans.reduce(0, +) / Double(cellMeans.count)
        let worst = cellMeans.map { abs($0 - overallMean) }.max() ?? 0
        return worst
    }

    /// Near-saturated pixels in the eye band. A glare proxy, not a glasses
    /// detector: it can raise `cannotVerify` but it never produces a `fail`.
    private static func glareSuspected(in sample: SampledImage, geometry: FaceGeometry) -> Bool {
        let bandTop = geometry.eyeY - 0.015
        let bandBottom = geometry.eyeY + 0.045
        guard bandBottom > bandTop else { return false }
        let halfWidth = max(0.05, geometry.faceWidth * 0.5)
        let rect = PixelSampling.clamp(
            CGRect(
                x: geometry.faceCenterX - halfWidth,
                y: bandTop,
                width: halfWidth * 2,
                height: bandBottom - bandTop
            )
        )
        guard let bounds = sample.pixelBounds(for: rect) else { return false }

        var bright = 0
        var total = 0
        for y in bounds.minY...bounds.maxY {
            for x in bounds.minX...bounds.maxX {
                total += 1
                if sample.luminance(x: x, y: y) > 0.97 { bright += 1 }
            }
        }
        guard total > 0 else { return false }
        return Double(bright) / Double(total) > 0.02
    }
}

// MARK: - Formatting

/// One place for every number that reaches a screen, so units and the en dash
/// stay consistent.
enum MeasurementFormat {

    static func number(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    /// "27.4 mm" / "2.1%" — no space before a percent sign.
    static func millimetresValue(_ value: Double) -> String {
        number(value) + " mm"
    }

    static func percent(_ value: Double) -> String {
        number(value) + "%"
    }

    /// "25.4 – 34.9 mm", "0.0 – 4.5%", or "1200.0 px and above" when there is
    /// no upper bound. The separator is an en dash, not a hyphen.
    static func range(_ lower: Double, _ upper: Double?, unit: String) -> String {
        let suffix: String
        if unit.isEmpty {
            suffix = ""
        } else if unit == "%" {
            suffix = "%"
        } else {
            suffix = " " + unit
        }
        guard let upper else {
            return number(lower) + suffix + " and above"
        }
        return number(lower) + " – " + number(upper) + suffix
    }

    static func millimetres(value: Double, lowerBound: Double, upperBound: Double) -> Measurement {
        Measurement(
            value: value,
            unit: "mm",
            lowerBound: lowerBound,
            upperBound: upperBound,
            displayValue: millimetresValue(value),
            displayRange: range(lowerBound, upperBound, unit: "mm")
        )
    }
}
