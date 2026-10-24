//
//  BackgroundAnalyzer.swift
//  PassportProof
//
//  Measures the background. Never replaces it.
//
//  This is a threshold test, not a perceptual one: the sources say any residual
//  original-background pixels at the hair edge are a problem, and that there is
//  no perceptual tolerance to appeal to. The numbers used here are prototype
//  defaults — the sources give no numeric threshold for the capture gate.
//

import Foundation
import CoreGraphics

struct BackgroundReport: Sendable {
    /// Standard deviation of background luminance, 0…1.
    let uniformitySigma: Double
    /// |head − background| at the crown, 0…1. Drives the shutter gate.
    let crownContrast: Double
    /// Fraction of the ring just outside the head whose colour deviates from
    /// the background, 0…1.
    let edgeResidualFraction: Double
    /// Normalised rects, origin top-left, where the background is not uniform.
    let failingRegions: [CGRect]
}

enum BackgroundAnalyzer {

    // MARK: - Thresholds (prototype defaults, one struct, tunable)

    static let uniformitySigmaLimit = 0.045
    static let crownContrastLimit = 0.18
    static let edgeResidualFractionLimit = 0.002

    // MARK: - Analysis

    static func analyze(_ image: CGImage, faceBox: CGRect) -> BackgroundReport {
        guard let sample = SampledImage(image: image) else {
            return BackgroundReport(
                uniformitySigma: 1,
                crownContrast: 0,
                edgeResidualFraction: 1,
                failingRegions: []
            )
        }

        let clampedFace = PixelSampling.clamp(faceBox)
        // Never sample inside the face, and never sample where hair is likely
        // to be: the corner blocks and the outer columns only.
        let exclusion = PixelSampling.expand(clampedFace, by: 0.02)

        let backgroundRegions = [
            CGRect(x: 0, y: 0, width: 0.12, height: 0.45),
            CGRect(x: 0.88, y: 0, width: 0.12, height: 0.45),
            CGRect(x: 0, y: 0, width: 0.35, height: 0.08),
            CGRect(x: 0.65, y: 0, width: 0.35, height: 0.08)
        ]

        let sigma = sample.luminanceSigma(inNormalizedRects: backgroundRegions, excluding: exclusion) ?? 1
        let backgroundLuminance = sample.meanLuminance(inNormalizedRects: backgroundRegions, excluding: exclusion) ?? 0

        let crownY = FaceAnalyzer.crownEnvelopeY(in: sample, faceBox: clampedFace) ?? Double(clampedFace.minY)

        let contrast = crownContrast(
            in: sample,
            crownY: crownY,
            faceBox: clampedFace,
            backgroundLuminance: backgroundLuminance
        )

        let edgeResidual = edgeResidualFraction(
            in: sample,
            crownY: crownY,
            faceBox: clampedFace,
            backgroundLuminance: backgroundLuminance
        )

        let regions = failingRegions(
            in: sample,
            faceBox: clampedFace,
            backgroundLuminance: backgroundLuminance
        )

        return BackgroundReport(
            uniformitySigma: min(max(sigma, 0), 1),
            crownContrast: min(max(contrast, 0), 1),
            edgeResidualFraction: min(max(edgeResidual, 0), 1),
            failingRegions: regions
        )
    }

    // MARK: - Crown contrast

    private static func crownContrast(
        in sample: SampledImage,
        crownY: Double,
        faceBox: CGRect,
        backgroundLuminance: Double
    ) -> Double {
        let halfWidth = max(0.06, Double(faceBox.width) * 0.45)
        let centre = Double(faceBox.midX)
        let bandTop = min(crownY + 0.01, 1)
        let bandBottom = min(crownY + 0.04, 1)
        guard bandBottom > bandTop else { return 0 }

        let band = CGRect(
            x: max(0, centre - halfWidth),
            y: bandTop,
            width: min(1, centre + halfWidth) - max(0, centre - halfWidth),
            height: bandBottom - bandTop
        )
        guard let headLuminance = sample.meanLuminance(inNormalizedRect: band) else { return 0 }
        return abs(headLuminance - backgroundLuminance)
    }

    // MARK: - Edge residual

    private static func edgeResidualFraction(
        in sample: SampledImage,
        crownY: Double,
        faceBox: CGRect,
        backgroundLuminance: Double
    ) -> Double {
        let horizontalPadding = Double(faceBox.width) * 0.12
        let headBox = PixelSampling.clamp(
            CGRect(
                x: Double(faceBox.minX) - horizontalPadding,
                y: crownY,
                width: Double(faceBox.width) + horizontalPadding * 2,
                height: max(Double(faceBox.maxY) - crownY, 0.02)
            )
        )

        let width = sample.width
        let height = sample.height
        let innerMinX = Int((Double(headBox.minX) * Double(width)).rounded(.down))
        let innerMaxX = Int((Double(headBox.maxX) * Double(width)).rounded(.up)) - 1
        let innerMinY = Int((Double(headBox.minY) * Double(height)).rounded(.down))
        let innerMaxY = Int((Double(headBox.maxY) * Double(height)).rounded(.up)) - 1

        let ringThickness = 2
        let outerMinX = max(innerMinX - ringThickness, 0)
        let outerMaxX = min(innerMaxX + ringThickness, width - 1)
        let outerMinY = max(innerMinY - ringThickness, 0)

        // R5 is about residual background at the *hair* edge. The lower third of
        // the head box runs over the neck and shoulders, where the subject is
        // clothing rather than background, so the ring stops above it.
        let ringBottom = innerMinY + Int(Double(innerMaxY - innerMinY) * 0.65)
        let outerMaxY = min(ringBottom, height - 1)

        guard outerMinX <= outerMaxX, outerMinY <= outerMaxY else { return 0 }

        var ringPixels = 0
        var deviating = 0
        for y in outerMinY...outerMaxY {
            for x in outerMinX...outerMaxX {
                let isInsideHead = x >= innerMinX && x <= innerMaxX && y >= innerMinY && y <= innerMaxY
                if isInsideHead { continue }
                ringPixels += 1
                if abs(sample.luminance(x: x, y: y) - backgroundLuminance) > 0.08 {
                    deviating += 1
                }
            }
        }
        guard ringPixels > 0 else { return 0 }
        return Double(deviating) / Double(ringPixels)
    }

    // MARK: - Failing regions

    private static func failingRegions(
        in sample: SampledImage,
        faceBox: CGRect,
        backgroundLuminance: Double
    ) -> [CGRect] {
        let divisions = 6
        let cellSize = 1.0 / Double(divisions)
        var regions: [CGRect] = []

        for row in 0..<divisions {
            for column in 0..<divisions {
                let rect = CGRect(
                    x: Double(column) * cellSize,
                    y: Double(row) * cellSize,
                    width: cellSize,
                    height: cellSize
                )
                // Only cells wholly outside the face are background evidence.
                if rect.intersects(PixelSampling.expand(faceBox, by: 0.01)) { continue }
                guard let mean = sample.meanLuminance(inNormalizedRect: rect),
                      let sigma = sample.luminanceSigma(inNormalizedRects: [rect], excluding: nil)
                else { continue }
                if sigma > uniformitySigmaLimit || abs(mean - backgroundLuminance) > 0.12 {
                    regions.append(rect)
                }
                if regions.count >= 6 { return regions }
            }
        }
        return regions
    }
}
