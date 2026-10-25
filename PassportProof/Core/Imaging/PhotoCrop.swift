//
//  PhotoCrop.swift
//  PassportProof
//
//  The single source of crop geometry. The crop editor, analysis preview,
//  print renderer and digital exporter all consume the same prepared pixels.
//

import CoreGraphics
import UIKit

struct CropTransform: Equatable, Sendable {
    /// Multiplier above the smallest aspect-fill crop. 1 uses the full source.
    var zoom: CGFloat
    /// Centre of the crop in full-source normalized coordinates.
    var center: CGPoint

    static let identity = CropTransform(zoom: 1, center: CGPoint(x: 0.5, y: 0.5))
}

enum PhotoCrop {
    static let zoomRange: ClosedRange<CGFloat> = 1...4

    /// Vision and pixel analysis do not benefit from a 12 MP crop whose largest
    /// output is 1200 px. Three times the largest output leaves ample resampling
    /// headroom while keeping analysis bounded and responsive.
    static let maximumPreparedDimension: CGFloat = 2048

    /// Uses facial geometry only to propose a crop. The user can adjust it and
    /// the validator still measures the resulting pixels independently.
    static func automaticTransform(for image: CGImage, spec: DocumentSpec) -> CropTransform {
        guard let geometry = FaceAnalyzer.geometry(of: image) else { return .identity }

        let imageSize = CGSize(width: image.width, height: image.height)
        let targetFraction = (spec.headHeightMM.lowerBound + spec.headHeightMM.upperBound) / 2 / spec.heightMM
        let baseHeight = cropRect(
            imageSize: imageSize,
            spec: spec,
            transform: .identity,
            integral: false
        ).height
        let desiredHeight = imageSize.height * CGFloat(geometry.headHeight) / CGFloat(targetFraction)
        let proposedZoom = baseHeight / max(desiredHeight, 1)
        let headCentreY = (geometry.crownInferredY + geometry.chinY) / 2
        let transform = CropTransform(
            zoom: proposedZoom.clamped(to: zoomRange),
            center: CGPoint(x: geometry.faceCenterX, y: headCentreY)
        )
        return clamped(transform, imageSize: imageSize, spec: spec)
    }

    static func clamped(
        _ transform: CropTransform,
        imageSize: CGSize,
        spec: DocumentSpec
    ) -> CropTransform {
        guard imageSize.width > 0, imageSize.height > 0 else { return .identity }
        let zoom = transform.zoom.clamped(to: zoomRange)
        let base = cropRect(
            imageSize: imageSize,
            spec: spec,
            transform: CropTransform(zoom: zoom, center: CGPoint(x: 0.5, y: 0.5)),
            integral: false
        )
        let xRange = (base.width / 2)...(imageSize.width - base.width / 2)
        let yRange = (base.height / 2)...(imageSize.height - base.height / 2)
        let center = CGPoint(
            x: (transform.center.x * imageSize.width).clamped(to: xRange) / imageSize.width,
            y: (transform.center.y * imageSize.height).clamped(to: yRange) / imageSize.height
        )
        return CropTransform(zoom: zoom, center: center)
    }

    /// The crop rectangle in source pixels. The normalized centre is converted
    /// only after applying zoom, so display gestures and output geometry agree.
    static func cropRect(
        imageSize: CGSize,
        spec: DocumentSpec,
        transform: CropTransform,
        integral: Bool = true
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }

        let aspect = CGFloat(spec.aspectRatio)
        var baseWidth = imageSize.width
        var baseHeight = baseWidth / aspect
        if baseHeight > imageSize.height {
            baseHeight = imageSize.height
            baseWidth = baseHeight * aspect
        }

        let zoom = transform.zoom.clamped(to: zoomRange)
        let width = baseWidth / zoom
        let height = baseHeight / zoom
        let centre = CGPoint(
            x: transform.center.x * imageSize.width,
            y: transform.center.y * imageSize.height
        )
        let minX = (centre.x - width / 2).clamped(to: 0...(imageSize.width - width))
        let minY = (centre.y - height / 2).clamped(to: 0...(imageSize.height - height))
        let precise = CGRect(x: minX, y: minY, width: width, height: height)
        guard integral else { return precise }

        let x = max(0, floor(precise.minX))
        let y = max(0, floor(precise.minY))
        let maxX = min(imageSize.width, ceil(precise.maxX))
        let maxY = min(imageSize.height, ceil(precise.maxY))
        return CGRect(x: x, y: y, width: max(1, maxX - x), height: max(1, maxY - y))
    }

    static func croppedCGImage(
        from image: CGImage,
        transform: CropTransform,
        spec: DocumentSpec
    ) -> CGImage? {
        let size = CGSize(width: image.width, height: image.height)
        let safe = clamped(transform, imageSize: size, spec: spec)
        let rect = cropRect(imageSize: size, spec: spec, transform: safe)
        // Small crops are returned for diagnosis too: the resolution rule can
        // then explain why export is blocked instead of hiding the photograph.
        guard let cropped = image.cropping(to: rect) else { return nil }
        let longestSide = CGFloat(max(cropped.width, cropped.height))
        guard longestSide > maximumPreparedDimension else { return cropped }

        let scale = maximumPreparedDimension / longestSide
        let width = max(1, Int((CGFloat(cropped.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(cropped.height) * scale).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { return nil }
        context.interpolationQuality = .high
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }

    static func croppedImage(
        from image: UIImage,
        transform: CropTransform,
        spec: DocumentSpec
    ) -> UIImage? {
        guard let source = ImageBridge.cgImage(from: image),
              let cropped = croppedCGImage(from: source, transform: transform, spec: spec) else {
            return nil
        }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
