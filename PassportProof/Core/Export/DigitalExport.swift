//
//  DigitalExport.swift
//  PassportProof
//
//  One file, at the document's portal geometry, with DPI written as metadata.
//  DPI is metadata, not a pixel property: the pixels are the pixels, and 300 is
//  what the portal reads.
//
//  The crop is geometric only — scale, translate, crop. No pixel is invented.
//

import Foundation
import CoreGraphics
import ImageIO

enum DigitalExport {

    static let dpi = 300
    static let compressionQuality = 0.95

    /// The JPEG uniform type identifier. Written literally to avoid pulling in
    /// a framework for one string.
    private static let jpegUTI = "public.jpeg" as CFString

    static func jpegData(from image: CGImage, spec: DocumentSpec) -> Data? {
        guard let rendered = fittedImage(from: image, spec: spec) else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            jpegUTI,
            1,
            nil
        ) else { return nil }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality,
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi
        ]

        CGImageDestinationAddImage(destination, rendered, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Geometry

    /// Scales and centre-crops to the document's exact pixel size, in sRGB.
    private static func fittedImage(from image: CGImage, spec: DocumentSpec) -> CGImage? {
        let targetWidth = spec.widthPixels
        let targetHeight = spec.heightPixels
        guard targetWidth > 0, targetHeight > 0, image.width > 0, image.height > 0 else { return nil }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .high
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Aspect-fill: cover the target, then centre the overflow off-frame.
        let scale = max(
            CGFloat(targetWidth) / CGFloat(image.width),
            CGFloat(targetHeight) / CGFloat(image.height)
        )
        let drawWidth = CGFloat(image.width) * scale
        let drawHeight = CGFloat(image.height) * scale
        let originX = (CGFloat(targetWidth) - drawWidth) / 2
        let originY = (CGFloat(targetHeight) - drawHeight) / 2
        context.draw(
            image,
            in: CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight)
        )

        return context.makeImage()
    }
}
