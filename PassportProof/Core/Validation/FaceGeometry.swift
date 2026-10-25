//
//  FaceGeometry.swift
//  PassportProof
//
//  Two crown estimators, because Vision has no crown.
//
//  `VNFaceLandmarks2D.faceContour` runs cheek to cheek *under* the chin and the
//  constellation carries no crown point at all. Passport rules measure the
//  skull, while the visa/DV composition template includes hair. Retain both:
//
//    1. the silhouette envelope — the top of the hair — scanned from pixels;
//    2. the crown inferred from chin-to-eye-line proportions.
//
//  Missing/uncertain crown evidence must not erase independently located eyes
//  and chin. The rule layer decides which head reference a workflow requires.
//

import Foundation
import CoreGraphics
import Vision

/// Normalised face geometry. **All y values are 0 at the top of the image and
/// 1 at the bottom**, which is the opposite of Vision's convention.
struct FaceGeometry: Sendable {
    /// Lowest point of the face contour, normalised from the top.
    let chinY: Double
    /// Mean y of the eye landmarks, normalised from the top.
    let eyeY: Double
    /// Top of the hair or head covering, from the pixel silhouette.
    let crownEnvelopeY: Double
    /// Crown implied by chin→eye proportions.
    let crownInferredY: Double
    /// Horizontal centre of the face box, 0…1.
    let faceCenterX: Double
    /// Width of the face box, normalised.
    let faceWidth: Double
    /// Vision's face box, converted to a top-left origin.
    let faceBox: CGRect
    /// True only when a separated silhouette was found above the face against
    /// a sufficiently uniform sampled background. A brow-box fallback is not
    /// a head measurement. Hand-constructed known geometry defaults to true.
    var hasCrownSilhouette: Bool = true

    /// Chin to inferred crown. Always positive for a detected face.
    var headHeight: Double { max(chinY - crownInferredY, 0) }

    /// Chin to the top of the hair.
    var headHeightEnvelope: Double { max(chinY - crownEnvelopeY, 0) }

    func headHeight(for reference: HeadMeasurement) -> Double {
        reference == .includingHair ? headHeightEnvelope : headHeight
    }

    /// A suggestion can use the facial estimate when no silhouette is visible;
    /// the later rule still reports that measurement as unresolved.
    func suggestedHeadHeight(for reference: HeadMeasurement) -> Double {
        reference == .includingHair && hasCrownSilhouette ? headHeightEnvelope : headHeight
    }

    /// How far the two estimators disagree, as a fraction of measured head
    /// height. Zero when the geometry was built by hand with agreeing values.
    var crownDivergence: Double {
        let height = headHeight
        guard height > 0.0001 else { return 1 }
        return abs(crownEnvelopeY - crownInferredY) / height
    }
}

enum FaceAnalyzer {

    // MARK: - Geometry

    static func geometry(of image: CGImage) -> FaceGeometry? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        // An applicant photo contains one person. Selecting the largest face
        // would silently discard evidence of a second person in the frame.
        guard let results = request.results, results.count == 1,
              let observation = results.first,
              let landmarks = observation.landmarks else { return nil }

        let imageSize = CGSize(width: image.width, height: image.height)
        guard imageSize.width > 0, imageSize.height > 0 else { return nil }

        // Vision's bounding box is normalised with a bottom-left origin. Flip
        // the origin so that the rest of the module can work top-down.
        let visionBox = observation.boundingBox
        let faceBox = CGRect(
            x: visionBox.minX,
            y: 1 - visionBox.maxY,
            width: visionBox.width,
            height: visionBox.height
        )

        let contour = topLeftPoints(of: landmarks.faceContour, in: visionBox) ?? []
        // The chin is the lowest point of the contour, which is the *largest*
        // y once the origin is at the top.
        guard let chinY = contour.map({ Double($0.y) }).max() else { return nil }
        let leftEye = topLeftPoints(of: landmarks.leftEye, in: visionBox)
            ?? topLeftPoints(of: landmarks.leftPupil, in: visionBox) ?? []
        let rightEye = topLeftPoints(of: landmarks.rightEye, in: visionBox)
            ?? topLeftPoints(of: landmarks.rightPupil, in: visionBox) ?? []
        guard !leftEye.isEmpty, !rightEye.isEmpty else { return nil }
        let leftEyeY = leftEye.map { Double($0.y) }.reduce(0, +) / Double(leftEye.count)
        let rightEyeY = rightEye.map { Double($0.y) }.reduce(0, +) / Double(rightEye.count)
        let eyeY = (leftEyeY + rightEyeY) / 2
        guard chinY.isFinite, eyeY.isFinite,
              chinY > eyeY, eyeY > 0, chinY <= 1 else { return nil }

        // The classic head: the eye line sits at the midpoint of crown and chin.
        // So crown = eye − (chin − eye). Clamped into the frame.
        let inferredCrown = min(max(2 * eyeY - chinY, 0), 1)

        let sample = SampledImage(image: image)
        let scanned = sample.flatMap { crownEnvelopeY(in: $0, faceBox: faceBox) }
        let envelope = scanned ?? Double(faceBox.minY)
        let backgroundSigma = sample?.luminanceSigma(inNormalizedRects: [
            CGRect(x: 0, y: 0, width: 0.30, height: 0.10),
            CGRect(x: 0.70, y: 0, width: 0.30, height: 0.10)
        ], excluding: nil)
        let hasSilhouette = scanned != nil
            && envelope > 1.0 / Double(SampledImage.standardSide)
            && envelope < eyeY
            && (backgroundSigma ?? 1) <= BackgroundAnalyzer.uniformitySigmaLimit
        // A bad crown scan used to reject all geometry, even when Vision had
        // located both eyes and chin. Keep those landmarks, and explicitly mark
        // crown-dependent rules unresolved instead of relaxing their threshold.

        return FaceGeometry(
            chinY: chinY,
            eyeY: eyeY,
            crownEnvelopeY: envelope,
            crownInferredY: inferredCrown,
            faceCenterX: Double(faceBox.midX),
            faceWidth: Double(faceBox.width),
            faceBox: faceBox,
            hasCrownSilhouette: hasSilhouette
        )
    }

    // MARK: - Silhouette

    /// Scans down from the top of the frame for the first row where enough
    /// pixels differ from the background to be a head. Returns a normalised
    /// top-origin y, or nil when nothing is found above the landmark box.
    ///
    /// This is only trustworthy on a plain, evenly lit background — which is
    /// exactly what the capture gate enforces before the shutter releases.
    static func crownEnvelopeY(in sample: SampledImage, faceBox: CGRect) -> Double? {
        let clampedFace = PixelSampling.clamp(faceBox)
        let backgroundRegions = [
            CGRect(x: 0, y: 0, width: 0.30, height: 0.10),
            CGRect(x: 0.70, y: 0, width: 0.30, height: 0.10)
        ]
        guard let background = sample.meanLuminance(inNormalizedRects: backgroundRegions, excluding: nil) else {
            return nil
        }

        // Scan the columns the head occupies, widened beyond the landmark box
        // because hair is wider than the face.
        let halfWidth = max(0.10, Double(clampedFace.width) * 0.72)
        let centre = Double(clampedFace.midX)
        let left = max(0, centre - halfWidth)
        let right = min(1, centre + halfWidth)
        guard right > left else { return nil }

        let leftPixel = Int((left * Double(sample.width)).rounded())
        let rightPixel = Int((right * Double(sample.width)).rounded())
        let span = max(rightPixel - leftPixel, 1)
        let requiredRun = max(Int(Double(span) * 0.28), 1)

        let stopRow = Int((Double(clampedFace.minY) * Double(sample.height)).rounded())
        let lastRow = min(max(stopRow, 0), sample.height - 1)
        guard lastRow > 0 else { return nil }

        for row in 0..<lastRow {
            var differing = 0
            for column in leftPixel..<max(leftPixel + 1, rightPixel) {
                if abs(sample.luminance(x: column, y: row) - background) > 0.10 {
                    differing += 1
                }
            }
            if differing >= requiredRun {
                return (Double(row) + 0.5) / Double(sample.height)
            }
        }
        return nil
    }

    // MARK: - Private

    /// Vision documents normalizedPoints relative to the face bounding box,
    /// with a lower-left origin. Map that explicit coordinate contract once.
    /// https://developer.apple.com/documentation/vision/vnfacelandmarks2d
    static func imagePoint(fromNormalizedFacePoint point: CGPoint, in boundingBox: CGRect) -> CGPoint {
        CGPoint(x: boundingBox.minX + point.x * boundingBox.width,
                y: 1 - (boundingBox.minY + point.y * boundingBox.height))
    }

    private static func topLeftPoints(
        of region: VNFaceLandmarkRegion2D?,
        in boundingBox: CGRect
    ) -> [CGPoint]? {
        guard let region else { return nil }
        let points = region.normalizedPoints
        guard !points.isEmpty else { return nil }
        return points.map { imagePoint(fromNormalizedFacePoint: $0, in: boundingBox) }
    }
}
