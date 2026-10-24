//
//  PixelSampling.swift
//  PassportProof
//
//  One downscale, many samples.
//
//  `CGImage` has no random-access pixel API. Touching a CGImage per pixel in a
//  loop is catastrophically slow, so every analyser in this module reads from a
//  single 256 × 256 RGBA8 buffer that is rasterised once.
//

import Foundation
import CoreGraphics

/// A small, row-major RGBA8 rasterisation of an image.
///
/// **Coordinate convention.** The buffer is drawn with `CGContext.draw(_:in:)`
/// into a full-frame rect. A bitmap context's memory starts at the top-left
/// pixel (round-tripping through `makeImage()` produces an upright image), so
/// **row 0 is the top of the image**. That matches `FaceGeometry`, whose
/// normalised y is 0 at the top, and it is why no flip appears anywhere below.
///
/// The buffer is square regardless of the source aspect ratio. That distortion
/// is harmless: every consumer indexes it with normalised coordinates, which
/// map linearly either way.
struct SampledImage {

    /// The side length used everywhere in this module.
    static let standardSide = 256

    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init?(image: CGImage, width: Int = 256, height: Int = 256) {
        guard width > 0, height > 0 else { return nil }
        let byteCount = width * height * 4
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: byteCount)
        pointer.initialize(repeating: 0, count: byteCount)
        defer { pointer.deallocate() }

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: pointer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.interpolationQuality = .high
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        self.width = width
        self.height = height
        self.bytes = Array(UnsafeBufferPointer(start: pointer, count: byteCount))
    }

    // MARK: - Sampling

    func red(x: Int, y: Int) -> Double { channel(x: x, y: y, offset: 0) }
    func green(x: Int, y: Int) -> Double { channel(x: x, y: y, offset: 1) }
    func blue(x: Int, y: Int) -> Double { channel(x: x, y: y, offset: 2) }

    func luminance(x: Int, y: Int) -> Double {
        // Rec. 709 luma. Perceptual weighting is enough here; nothing depends on
        // a colour-managed absolute value.
        0.2126 * red(x: x, y: y) + 0.7152 * green(x: x, y: y) + 0.0722 * blue(x: x, y: y)
    }

    func luminance(normalizedX x: Double, normalizedY y: Double) -> Double {
        luminance(x: Int((x * Double(width)).rounded()), y: Int((y * Double(height)).rounded()))
    }

    // MARK: - Region statistics

    /// Mean luma over a normalised rect with top-left origin.
    func meanLuminance(inNormalizedRect rect: CGRect) -> Double? {
        let bounds = pixelBounds(for: rect)
        guard let bounds else { return nil }
        var sum = 0.0
        var count = 0
        for y in bounds.minY...bounds.maxY {
            for x in bounds.minX...bounds.maxX {
                sum += luminance(x: x, y: y)
                count += 1
            }
        }
        guard count > 0 else { return nil }
        return sum / Double(count)
    }

    /// Population standard deviation of luma over a set of normalised rects,
    /// ignoring pixels that fall inside `excluding`.
    func luminanceSigma(inNormalizedRects rects: [CGRect], excluding: CGRect?) -> Double? {
        var values: [Double] = []
        for rect in rects {
            guard let bounds = pixelBounds(for: rect) else { continue }
            for y in bounds.minY...bounds.maxY {
                for x in bounds.minX...bounds.maxX {
                    if let excluding {
                        let nx = (Double(x) + 0.5) / Double(width)
                        let ny = (Double(y) + 0.5) / Double(height)
                        if excluding.contains(CGPoint(x: nx, y: ny)) { continue }
                    }
                    values.append(luminance(x: x, y: y))
                }
            }
        }
        guard !values.isEmpty else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        var sumSquares = 0.0
        for value in values {
            let delta = value - mean
            sumSquares += delta * delta
        }
        return (sumSquares / Double(values.count)).squareRoot()
    }

    /// Mean luma over a set of normalised rects, ignoring pixels inside `excluding`.
    func meanLuminance(inNormalizedRects rects: [CGRect], excluding: CGRect?) -> Double? {
        var sum = 0.0
        var count = 0
        for rect in rects {
            guard let bounds = pixelBounds(for: rect) else { continue }
            for y in bounds.minY...bounds.maxY {
                for x in bounds.minX...bounds.maxX {
                    if let excluding {
                        let nx = (Double(x) + 0.5) / Double(width)
                        let ny = (Double(y) + 0.5) / Double(height)
                        if excluding.contains(CGPoint(x: nx, y: ny)) { continue }
                    }
                    sum += luminance(x: x, y: y)
                    count += 1
                }
            }
        }
        guard count > 0 else { return nil }
        return sum / Double(count)
    }

    // MARK: - Private

    private func channel(x: Int, y: Int, offset: Int) -> Double {
        let clampedX = min(max(x, 0), width - 1)
        let clampedY = min(max(y, 0), height - 1)
        let index = (clampedY * width + clampedX) * 4 + offset
        guard index >= 0, index < bytes.count else { return 0 }
        return Double(bytes[index]) / 255.0
    }

    /// Integer pixel bounds for a normalised rect, clamped to the buffer.
    func pixelBounds(for rect: CGRect) -> (minX: Int, maxX: Int, minY: Int, maxY: Int)? {
        let normalised = PixelSampling.clamp(rect)
        let minX = Int((normalised.minX * CGFloat(width)).rounded(.down))
        let maxX = Int((normalised.maxX * CGFloat(width)).rounded(.up)) - 1
        let minY = Int((normalised.minY * CGFloat(height)).rounded(.down))
        let maxY = Int((normalised.maxY * CGFloat(height)).rounded(.up)) - 1
        let clampedMinX = min(max(minX, 0), width - 1)
        let clampedMaxX = min(max(maxX, 0), width - 1)
        let clampedMinY = min(max(minY, 0), height - 1)
        let clampedMaxY = min(max(maxY, 0), height - 1)
        guard clampedMinX <= clampedMaxX, clampedMinY <= clampedMaxY else { return nil }
        return (clampedMinX, clampedMaxX, clampedMinY, clampedMaxY)
    }
}

// MARK: - Geometry helpers

enum PixelSampling {

    /// Clamps a normalised rect into 0…1 on both axes.
    static func clamp(_ rect: CGRect) -> CGRect {
        let minX = min(max(rect.minX, 0), 1)
        let minY = min(max(rect.minY, 0), 1)
        let maxX = min(max(rect.maxX, minX), 1)
        let maxY = min(max(rect.maxY, minY), 1)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Grows a normalised rect by `amount` on every side, clamped to 0…1.
    static func expand(_ rect: CGRect, by amount: CGFloat) -> CGRect {
        clamp(rect.insetBy(dx: -amount, dy: -amount))
    }
}
