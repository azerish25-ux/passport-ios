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
    private(set) var findings: [Finding]
    let geometry: FaceGeometry?
    let background: BackgroundReport?
    private(set) var overall: FindingStatus
    let imagePixelSize: CGSize
    let captureDate: Date?
    let shadowDelta: Double?
    let glareSuspected: Bool
    private(set) var review: PhotoReview

    var failures: [Finding] { findings.filter { $0.status == .fail } }
    var unresolved: [Finding] { findings.filter { $0.status == .cannotVerify } }

    /// Reapplies only the rule layer after a visual confirmation. Expensive
    /// Vision and pixel signals are reused, while the displayed review state
    /// and the exported readiness decision stay in lockstep.
    mutating func update(review: PhotoReview, spec: DocumentSpec) {
        let updated = ValidationEngine.findings(
            geometry: geometry,
            background: background,
            spec: spec,
            imagePixelSize: imagePixelSize,
            captureDate: captureDate,
            shadowDelta: shadowDelta,
            glareSuspected: glareSuspected,
            review: review,
            referenceDate: Date()
        )
        findings = updated
        overall = ValidationEngine.overall(for: updated)
        self.review = review
    }
}

// MARK: - Engine

enum ValidationEngine {
    static let crownDivergenceLimit = 0.06
    static let centringToleranceMM = 3.0
    static let shadowDeltaLimit = 0.22

    // MARK: - Analysis

    static func analyze(
        image: CGImage,
        spec: DocumentSpec,
        captureDate: Date? = nil,
        review: PhotoReview = .pending
    ) -> PhotoAnalysis {
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
            glareSuspected: suspectedGlare,
            review: review,
            referenceDate: Date()
        )

        return PhotoAnalysis(
            findings: allFindings,
            geometry: geometry,
            background: background,
            overall: overall(for: allFindings),
            imagePixelSize: pixelSize,
            captureDate: captureDate,
            shadowDelta: measuredShadowDelta,
            glareSuspected: suspectedGlare,
            review: review
        )
    }

    /// Deterministic rule-only entry point used by unit tests and cached review
    /// updates. Optional signals remain `cannotVerify` when unavailable.
    static func findings(
        geometry: FaceGeometry?,
        background: BackgroundReport?,
        spec: DocumentSpec,
        imagePixelSize: CGSize,
        captureDate: Date?,
        shadowDelta: Double? = nil,
        glareSuspected: Bool = false,
        review: PhotoReview = .pending,
        referenceDate: Date = Date()
    ) -> [Finding] {
        var output: [Finding] = [headHeight(geometry: geometry, spec: spec)]
        if spec.headHeightShare != nil {
            output.append(headHeightShare(geometry: geometry, spec: spec))
        }
        if spec.eyeLineFromBottomMM != nil {
            output.append(eyeLine(geometry: geometry, spec: spec))
        }
        output.append(contentsOf: [
            centring(geometry: geometry, spec: spec),
            backgroundUniformity(background: background),
            shadow(delta: shadowDelta),
            expression(geometry: geometry, review: review),
            glasses(review: review, glareSuspected: glareSuspected),
            resolution(imagePixelSize: imagePixelSize, spec: spec),
            photoAge(
                captureDate: captureDate,
                spec: spec,
                review: review,
                referenceDate: referenceDate
            ),
            noManipulation(review: review)
        ])
        return output
    }

    // MARK: - Aggregation

    static func overall(for findings: [Finding]) -> FindingStatus {
        if findings.contains(where: { $0.status == .fail }) { return .fail }
        if findings.contains(where: { $0.status == .cannotVerify }) { return .cannotVerify }
        return .pass
    }

    // MARK: R1 / R2 — head height

    private static func canMeasureHead(_ geometry: FaceGeometry, spec: DocumentSpec) -> Bool {
        guard geometry.hasCrownSilhouette else { return false }
        switch spec.headMeasurement {
        case .skull:
            return geometry.crownInferredY > 0 && geometry.crownDivergence <= crownDivergenceLimit
        case .includingHair:
            return geometry.crownEnvelopeY > 0 && geometry.crownEnvelopeY < geometry.eyeY
                && geometry.headHeightEnvelope > 0.02
        }
    }

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

        let measuredMM = geometry.headHeight(for: spec.headMeasurement) * spec.heightMM
        let measurement = MeasurementFormat.millimetres(
            value: measuredMM,
            lowerBound: range.lowerBound,
            upperBound: range.upperBound
        )

        if !canMeasureHead(geometry, spec: spec) {
            return Finding(
                id: .headHeight,
                title: "Head height",
                status: .cannotVerify,
                detail: spec.headMeasurement == .skull
                    ? "The anatomical crown is estimated from facial proportions, not a Vision landmark. The visible outline is unavailable or does not sufficiently agree with that estimate. Hair volume, a covering or a clipped head can cause this. Check the original with the issuer's template; this is not a verified skull measurement."
                    : "The top of the head including hair could not be separated reliably from the background, or touches the frame edge. Retake with the entire head visible against a plain background. The eye and chin landmarks remain available independently.",
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
                detail: "The \(spec.headMeasurement.description) estimate is \(formatted) mm. This workflow requires \(rangeText). Crop tighter or move closer.",
                measurement: measurement,
                provenance: .source
            )
        }
        if measuredMM > range.upperBound {
            return Finding(
                id: .headHeight,
                title: "Head height",
                status: .fail,
                detail: "The \(spec.headMeasurement.description) estimate is \(formatted) mm. This workflow requires \(rangeText). Crop looser or move back.",
                measurement: measurement,
                provenance: .source
            )
        }
        return Finding(
            id: .headHeight,
            title: "Head height",
            status: .pass,
            detail: "The \(spec.headMeasurement.description) estimate is \(formatted) mm, inside \(rangeText). Confirm the outline against the original; the issuer makes the final decision.",
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

        // Both head-based findings use the workflow's same measurement basis.
        if !canMeasureHead(geometry, spec: spec) {
            return Finding(
                id: .headHeightShare,
                title: "Head height share",
                status: .cannotVerify,
                detail: "The required head outline is unresolved, so the head's share of the frame cannot be measured reliably.",
                measurement: nil,
                provenance: .source
            )
        }

        let measured = geometry.headHeight(for: spec.headMeasurement)
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

        // Eye landmarks do not depend on the skull/hair estimate. An uncertain
        // crown must not erase an independently measured eye-line position.
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
                provenance: .appDefault
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
                detail: "The face centre sits \(MeasurementFormat.number(offsetMM)) mm off the middle of the frame, to the \(side). The app tolerance is \(rangeText). Re-crop so the face is centred.",
                measurement: measurement,
                provenance: .appDefault
            )
        }
        return Finding(
            id: .centring,
            title: "Centring",
            status: .pass,
            detail: "The face centre is \(MeasurementFormat.number(offsetMM)) mm from the middle of the frame, inside the app tolerance of \(rangeText).",
            measurement: measurement,
            provenance: .appDefault
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
                provenance: .appDefault
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
        let base = "Sampled background spread is \(MeasurementFormat.percent(sigmaPercent)) (app limit \(rangeText)). The rectangular edge sample differs from the background in \(MeasurementFormat.percent(residualPercent)) of its pixels; it is not a subject mask."

        guard let color = background.color else {
            return Finding(
                id: .backgroundUniformity,
                title: "Background colour and uniformity",
                status: .cannotVerify,
                detail: "The background colour could not be measured. Use a plain white or off-white wall and check the original photograph.",
                measurement: measurement,
                provenance: .appDefault
            )
        }
        if color.status == .fail {
            return Finding(
                id: .backgroundUniformity,
                title: "Background colour and uniformity",
                status: .fail,
                detail: "The sampled background appears coloured or too dark. These US workflows require white or off-white; a uniform blue, grey or dark wall is not sufficient. Retake against a suitable wall without replacing the background digitally. Colour thresholds are app-selected screening tolerances.",
                measurement: measurement,
                provenance: .appDefault
            )
        }

        if background.uniformitySigma > BackgroundAnalyzer.uniformitySigmaLimit {
            return Finding(
                id: .backgroundUniformity,
                title: "Background uniformity",
                status: .fail,
                detail: base + " The background is not even. Stand further from the wall, face a single light source, and avoid a wall that is lit unevenly across the frame.",
                measurement: measurement,
                provenance: .appDefault
            )
        }
        if background.edgeResidualFraction > BackgroundAnalyzer.edgeResidualFractionLimit {
            return Finding(
                id: .backgroundUniformity,
                title: "Background uniformity",
                status: .cannotVerify,
                detail: base + " Natural hair, ears or clothing can cross this sample. Inspect the original around the entire head for background objects, shadows or editing halos. This signal cannot establish that the background was replaced, and natural hair should not be removed to satisfy it.",
                measurement: measurement,
                provenance: .appDefault
            )
        }
        if color.status == .cannotVerify {
            return Finding(
                id: .backgroundUniformity,
                title: "Background colour and uniformity",
                status: .cannotVerify,
                detail: "The background is near the app's white/off-white screening boundary. Inspect the original in neutral light or retake against a brighter, plain wall. The issuer does not publish an RGB threshold.",
                measurement: measurement,
                provenance: .appDefault
            )
        }
        return Finding(
            id: .backgroundUniformity,
            title: "Background uniformity",
            status: .pass,
            detail: base,
            measurement: measurement,
            provenance: .appDefault
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
                provenance: .appDefault
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
                detail: "Luminance varies by \(MeasurementFormat.number(delta)) across the face; the app-selected limit is \(MeasurementFormat.number(shadowDeltaLimit)). Turn to face the light so both sides of the face are lit evenly.",
                measurement: measurement,
                provenance: .appDefault
            )
        }
        return Finding(
            id: .shadow,
            title: "Shadow",
            status: .pass,
            detail: "Luminance varies by \(MeasurementFormat.number(delta)) across the face, inside the app-selected limit of \(MeasurementFormat.number(shadowDeltaLimit)).",
            measurement: measurement,
            provenance: .appDefault
        )
    }

    // MARK: R11 — expression

    private static func expression(geometry: FaceGeometry?, review: PhotoReview) -> Finding {
        guard geometry != nil else {
            return Finding(
                id: .expression,
                title: "Expression",
                status: .cannotVerify,
                detail: "No face was detected, so expression and open eyes need a clearer photograph.",
                measurement: nil,
                provenance: .source
            )
        }
        guard review.expressionConfirmed else {
            return Finding(
                id: .expression,
                title: "Expression",
                status: .cannotVerify,
                detail: "Use the visual checklist to confirm the expression requirement for this document.",
                measurement: nil,
                provenance: .source
            )
        }
        return Finding(
            id: .expression,
            title: "Expression",
            status: .pass,
            detail: "You visually confirmed the expression requirement. The issuer still reviews the submitted photograph.",
            measurement: nil,
            provenance: .source
        )
    }

    // MARK: R12 — glasses

    private static func glasses(review: PhotoReview, glareSuspected: Bool) -> Finding {
        if glareSuspected {
            return Finding(
                id: .glasses,
                title: "Glasses and eye visibility",
                status: .cannotVerify,
                detail: "Bright pixels around the eyes may be glare. Inspect the original closely and retake if frames, reflection or shadow obscure either eye.",
                measurement: nil,
                provenance: .source
            )
        }
        guard review.glassesConfirmed else {
            return Finding(
                id: .glasses,
                title: "Glasses and eye visibility",
                status: .cannotVerify,
                detail: "Use the visual checklist to confirm the glasses rule and that both eyes are fully visible.",
                measurement: nil,
                provenance: .source
            )
        }
        return Finding(
            id: .glasses,
            title: "Glasses and eye visibility",
            status: .pass,
            detail: "You visually confirmed the glasses requirement and unobstructed eyes; no glasses detector is claimed.",
            measurement: nil,
            provenance: .source
        )
    }

    // MARK: R6 / G9 — prepared-crop resolution

    private static func resolution(imagePixelSize: CGSize, spec: DocumentSpec) -> Finding {
        let requiredWidth = spec.widthPixels
        let requiredHeight = spec.heightPixels
        let width = Int(imagePixelSize.width.rounded())
        let height = Int(imagePixelSize.height.rounded())
        let shortSide = min(width, height)
        let requiredShortSide = min(requiredWidth, requiredHeight)
        let rangeText = "\(requiredWidth) × \(requiredHeight) px minimum"
        let measurement = Measurement(
            value: Double(shortSide),
            unit: "px",
            lowerBound: Double(requiredShortSide),
            upperBound: nil,
            displayValue: "\(width) × \(height) px",
            displayRange: rangeText
        )

        if width < requiredWidth || height < requiredHeight {
            return Finding(
                id: .resolution,
                title: "Crop resolution",
                status: .fail,
                detail: "This crop is \(width) × \(height) px; the output needs at least \(requiredWidth) × \(requiredHeight) px. Zoom out or choose a higher-resolution original rather than inventing pixels.",
                measurement: measurement,
                provenance: .source
            )
        }
        return Finding(
            id: .resolution,
            title: "Crop resolution",
            status: .pass,
            detail: "The prepared crop is \(width) × \(height) px and covers the \(requiredWidth) × \(requiredHeight) px output without forced upscaling.",
            measurement: measurement,
            provenance: .source
        )
    }

    // MARK: R7 — photo age

    private static func photoAge(
        captureDate: Date?,
        spec: DocumentSpec,
        review: PhotoReview,
        referenceDate: Date
    ) -> Finding {
        let limit = spec.maximumPhotoAgeMonths
        let rangeText = MeasurementFormat.range(0, limit, unit: "months")

        guard let captureDate else {
            if review.recentPhotoConfirmed {
                return Finding(
                    id: .photoAge,
                    title: "Photo age",
                    status: .pass,
                    detail: "No EXIF capture date was available. You confirmed that the photograph meets the \(MeasurementFormat.number(limit))-month recency requirement.",
                    measurement: nil,
                    provenance: .source
                )
            }
            return Finding(
                id: .photoAge,
                title: "Photo age",
                status: .cannotVerify,
                detail: "This image has no readable capture date. Confirm its recency in the visual checklist; the limit is \(MeasurementFormat.number(limit)) months.",
                measurement: nil,
                provenance: .source
            )
        }

        let interval = referenceDate.timeIntervalSince(captureDate)
        guard interval >= -300 else {
            return Finding(
                id: .photoAge,
                title: "Photo age",
                status: .cannotVerify,
                detail: "The capture date is in the future. Check the source file and device clock rather than treating a negative age as recent.",
                measurement: nil,
                provenance: .source
            )
        }

        let months = max(0, interval / (60 * 60 * 24 * 30.44))
        let measurement = Measurement(
            value: months,
            unit: "months",
            lowerBound: 0,
            upperBound: limit,
            displayValue: MeasurementFormat.number(months) + " months",
            displayRange: rangeText
        )

        if let cutoff = Calendar(identifier: .gregorian).date(byAdding: .month, value: -Int(limit), to: referenceDate),
           captureDate < cutoff {
            return Finding(
                id: .photoAge,
                title: "Photo age",
                status: .fail,
                detail: "The photograph is older than the \(MeasurementFormat.number(limit))-month limit. Take a new photograph that reflects your current appearance.",
                measurement: measurement,
                provenance: .source
            )
        }
        return Finding(
            id: .photoAge,
            title: "Photo age",
            status: .pass,
            detail: "The capture date is inside the \(MeasurementFormat.number(limit))-month limit for this document.",
            measurement: measurement,
            provenance: .source
        )
    }

    // MARK: R14 / R16 — no manipulation

    private static func noManipulation(review: PhotoReview) -> Finding {
        guard review.originalUneditedConfirmed else {
            return Finding(
                id: .noManipulation,
                title: "Original, unedited photo",
                status: .cannotVerify,
                detail: "Confirm that the source was not filtered, retouched or digitally altered before the geometric crop in this app.",
                measurement: nil,
                provenance: .source
            )
        }
        return Finding(
            id: .noManipulation,
            title: "Original, unedited photo",
            status: .pass,
            detail: "You confirmed an unaltered source. PassportProof applies only the reviewed geometric crop and output resizing—no retouching, filters or synthesis.",
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
