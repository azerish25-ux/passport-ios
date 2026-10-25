//
//  DigitalExport.swift
//  PassportProof
//
//  Encodes the prepared crop at the document's exact geometry. No independent
//  crop happens here. Compression is bounded and the issuer's byte ceiling is
//  checked on the actual encoded data rather than assumed from a quality value.
//

import Foundation
import CoreGraphics
import ImageIO

enum DigitalExport {
    static let dpi = 300
    static let compressionQuality = 0.95
    private static let jpegUTI = "public.jpeg" as CFString

    static func jpegData(from preparedImage: CGImage, spec: DocumentSpec) -> Data? {
        guard let rendered = resizedImage(from: preparedImage, spec: spec) else { return nil }

        if let maximum = spec.maximumFileSizeBytes {
            for step in 0...12 {
                let quality = compressionQuality - Double(step) * 0.05
                guard let data = encode(rendered, quality: quality) else { return nil }
                if data.count <= maximum { return data }
            }
            return nil
        }

        return encode(rendered, quality: compressionQuality)
    }

    private static func encode(_ image: CGImage, quality: Double) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, jpegUTI, 1, nil) else {
            return nil
        }
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: max(0.35, quality),
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
            kCGImagePropertyColorModel: "RGB"
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    /// Resizes the prepared crop only. Aspect is validated instead of silently
    /// introducing a second, potentially different centre crop.
    private static func resizedImage(from image: CGImage, spec: DocumentSpec) -> CGImage? {
        let targetWidth = spec.widthPixels
        let targetHeight = spec.heightPixels
        guard targetWidth > 0, targetHeight > 0, image.width > 0, image.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        let sourceAspect = Double(image.width) / Double(image.height)
        let targetAspect = Double(targetWidth) / Double(targetHeight)
        guard abs(sourceAspect - targetAspect) < 0.02 else { return nil }

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
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight)
        )
        return context.makeImage()
    }
}
