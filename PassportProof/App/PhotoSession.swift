//
//  PhotoSession.swift
//  PassportProof
//
//  The single in-memory home for the photo under measurement.
//
//  Prohibition P1: this object lives for the session only. It writes nothing to
//  disk, caches nothing, and is deliberately not Codable. Killing the app is the
//  deletion path.
//

import SwiftUI
import UIKit

@MainActor
final class PhotoSession: ObservableObject {

    /// The photo as the user sees it.
    @Published private(set) var image: UIImage?

    /// The same photo as pixels, orientation applied. The engine consumes this.
    @Published private(set) var cgImage: CGImage?

    /// The gate result for the current photo, evaluated on the still.
    @Published var gate: CaptureGateResult?

    /// Result for the photo above, and the document it was measured against.
    @Published var analysis: PhotoAnalysis?
    @Published var analyzedDocumentID: String?

    /// Last print layout chosen. Kept here so the picker survives a back-tap.
    @Published var layout: PrintSheetLayout = .fourBySix

    var hasPhoto: Bool { cgImage != nil }

    func adopt(_ image: UIImage) {
        self.image = image
        self.cgImage = ImageBridge.cgImage(from: image)
        self.analysis = nil
        self.analyzedDocumentID = nil
        self.gate = nil
    }

    func store(_ analysis: PhotoAnalysis, for documentID: String) {
        self.analysis = analysis
        self.analyzedDocumentID = documentID
    }

    func clear() {
        image = nil
        cgImage = nil
        gate = nil
        analysis = nil
        analyzedDocumentID = nil
    }
}

// MARK: - UIImage to CGImage

enum ImageBridge {

    /// Returns the photo as a `CGImage` with its orientation baked in.
    ///
    /// `UIImage.cgImage` ignores `imageOrientation`, so a portrait photo from the
    /// library would otherwise reach the face detector rotated. The redraw is a
    /// rotation/flip at the original pixel size — geometric only, which is the
    /// only transformation G7 permits. No scaling, no resampling of content.
    static func cgImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let redrawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return redrawn.cgImage
    }
}
