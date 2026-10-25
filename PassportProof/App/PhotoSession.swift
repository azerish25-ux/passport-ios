//
//  PhotoSession.swift
//  PassportProof
//
//  The single in-memory home for the prepared photograph. Nothing is Codable
//  and no image is persisted. Preview, diagnosis and export consume these same
//  cropped pixels so a finding can never describe a different output.
//

import SwiftUI
import UIKit

@MainActor
final class PhotoSession: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var cgImage: CGImage?
    @Published private(set) var captureDate: Date?
    @Published private(set) var review = PhotoReview.pending
    @Published private(set) var revision = UUID()

    @Published var gate: CaptureGateResult?
    @Published private(set) var analysis: PhotoAnalysis?
    @Published private(set) var analyzedDocumentID: String?
    @Published var layout: PrintSheetLayout = .fourBySix

    var hasPhoto: Bool { cgImage != nil }

    /// Adopts the final, user-reviewed crop. Later stages never apply another
    /// independent centre crop.
    func adopt(_ image: UIImage, captureDate: Date? = nil) {
        self.image = image
        self.cgImage = ImageBridge.cgImage(from: image)
        self.captureDate = captureDate
        self.review = .pending
        self.analysis = nil
        self.analyzedDocumentID = nil
        self.gate = nil
        self.revision = UUID()
    }

    func store(_ analysis: PhotoAnalysis, for documentID: String) {
        self.analysis = analysis
        self.analyzedDocumentID = documentID
    }

    func updateReview(_ review: PhotoReview) {
        self.review = review
        guard var analysis,
              let analyzedDocumentID,
              let spec = DocumentCorpus.document(id: analyzedDocumentID) else { return }
        analysis.update(review: review, spec: spec)
        self.analysis = analysis
    }

    func canExport(for spec: DocumentSpec) -> Bool {
        guard hasPhoto,
              analyzedDocumentID == spec.id,
              review.allConfirmed,
              let analysis else { return false }
        return analysis.failures.isEmpty
    }

    func clear() {
        image = nil
        cgImage = nil
        gate = nil
        analysis = nil
        analyzedDocumentID = nil
        captureDate = nil
        review = .pending
        revision = UUID()
    }
}

// MARK: - UIImage to CGImage

enum ImageBridge {
    /// Returns pixels with EXIF orientation baked in. `UIImage.cgImage` alone
    /// ignores `imageOrientation` and would rotate the validator's input.
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
