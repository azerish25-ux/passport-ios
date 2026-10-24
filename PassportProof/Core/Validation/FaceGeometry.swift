//
//  FaceGeometry.swift
//  PassportProof
//
//  Two crown estimators, because Vision has no crown.
//
//  `VNFaceLandmarks2D.faceContour` runs cheek to cheek *under* the chin and the
//  constellation carries no crown point at all. The regulated measurement is
//  chin to top of skull, which stops at the bone and not at the hair. So we
//  take two readings:
//
//    1. the silhouette envelope — the top of the hair — scanned from pixels;
//    2. the crown inferred from chin-to-eye-line proportions.
//
//  When they disagree the answer is `cannotVerify`, never pass and never fail.
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

    /// Chin to inferred crown. Always positive for a detected face.
    var headHeight: Double { max(chinY - crownInferredY, 0) }

    /// Chin to the top of the hair.
    var headHeightEnvelope: Double { max(chinY - crownEnvelopeY, 0) }

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

        guard let results = request.results, !results.isEmpty else { return nil }

        // The subject is the largest face. A second face in the background is
        // not what the document is about.
        let observation = results.max { lhs, rhs in
            area(of: lhs) < area(of: rhs)
        }
        guard let observation, let landmarks = observation.landmarks else { return nil }

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

        let contour = topLeftPoints(of: landmarks.faceContour, imageSize: imageSize) ?? []
        // The chin is the lowest point of the contour, which is the *largest*
        // y once the origin is at the top.
        let chinY: Double = contour.map { Double($0.y) }.max() ?? Double(faceBox.maxY)

        var eyePoints: [CGPoint] = []
        eyePoints.append(contentsOf: topLeftPoints(of: landmarks.leftEye, imageSize: imageSize) ?? [])
        eyePoints.append(contentsOf: topLeftPoints(of: landmarks.rightEye, imageSize: imageSize) ?? [])
        if eyePoints.isEmpty {
            eyePoints.append(contentsOf: topLeftPoints(of: landmarks.leftPupil, imageSize: imageSize) ?? [])
            eyePoints.append(contentsOf: topLeftPoints(of: landmarks.rightPupil, imageSize: imageSize) ?? [])
        }
        guard !eyePoints.isEmpty else { return nil }
        let eyeY: Double = eyePoints.map { Double($0.y) }.reduce(0, +) / Double(eyePoints.count)

        // The classic head: the eye line sits at the midpoint of crown and chin.
        // So crown = eye − (chin − eye). Clamped into the frame.
        let inferredCrown = min(max(2 * eyeY - chinY, 0), 1)

        let envelope: Double
        if let sample = SampledImage(image: image),
           let scanned = crownEnvelopeY(in: sample, faceBox: faceBox) {
            envelope = scanned
        } else {
            // No usable silhouette. Fall back to the top of the landmark box,
            // which sits near the brow — deliberately conservative, because it
            // makes the two estimators diverge and the rule report
            // `cannotVerify` rather than guess.
            envelope = Double(faceBox.minY)
        }

        guard chinY > eyeY, eyeY > 0 else { return nil }

        return FaceGeometry(
            chinY: chinY,
            eyeY: eyeY,
            crownEnvelopeY: envelope,
            crownInferredY: inferredCrown,
            faceCenterX: Double(faceBox.midX),
            faceWidth: Double(faceBox.width),
            faceBox: faceBox
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

    private static func area(of observation: VNFaceObservation) -> CGFloat {
        observation.boundingBox.width * observation.boundingBox.height
    }

    /// Vision landmark points, converted to **top-left** normalised image space.
    ///
    /// `pointsInImage(imageSize:)` returns points in image coordinates with the
    /// origin at the **bottom-left**. Everything in this module is top-left, so
    /// the flip below is load-bearing: drop it and every vertical measurement
    /// inverts, producing a validator that is wrong in both directions.
    private static func topLeftPoints(
        of region: VNFaceLandmarkRegion2D?,
        imageSize: CGSize
    ) -> [CGPoint]? {
        guard let region else { return nil }
        let points = region.pointsInImage(imageSize: imageSize)
        guard !points.isEmpty else { return nil }
        return points.map { point in
            CGPoint(
                x: point.x / imageSize.width,
                y: 1 - point.y / imageSize.height
            )
        }
    }
}
