//
//  PhotoSession.swift
//  PassportProof
//
//  An accepted photo and its uncropped working original, held only in memory.
//  Editing is transactional: opening or cancelling an editor does not change
//  the accepted pixels, diagnosis or confirmations.
//

import SwiftUI
import UIKit

struct PreparedPhotoCrop {
    let originalImage: UIImage
    let image: UIImage
    let transform: CropTransform
    let rotationQuarterTurns: Int
}

struct PhotoEditContext: Identifiable {
    let id: UUID
    let originalImage: UIImage
    let captureDate: Date?
    let transform: CropTransform?
    let rotationQuarterTurns: Int
    let documentID: String

    init(
        id: UUID = UUID(),
        originalImage: UIImage,
        captureDate: Date? = nil,
        transform: CropTransform? = nil,
        rotationQuarterTurns: Int = 0,
        documentID: String
    ) {
        self.id = id
        self.originalImage = originalImage
        self.captureDate = captureDate
        self.transform = transform
        self.rotationQuarterTurns = rotationQuarterTurns
        self.documentID = documentID
    }
}

@MainActor
final class PhotoSession: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var cgImage: CGImage?
    @Published private(set) var originalImage: UIImage?
    @Published private(set) var acceptedDocumentID: String?
    @Published private(set) var cropTransform: CropTransform = .identity
    @Published private(set) var rotationQuarterTurns = 0
    @Published private(set) var captureDate: Date?
    @Published private(set) var review = PhotoReview.pending
    @Published private(set) var revision = UUID()

    @Published var gate: CaptureGateResult?
    @Published private(set) var analysis: PhotoAnalysis?
    @Published private(set) var analyzedDocumentID: String?
    @Published private(set) var manualFraming: ManualFramingRecord?
    @Published var layout: PrintSheetLayout = .fourBySix

    var hasPhoto: Bool { cgImage != nil }

    func hasPhoto(for spec: DocumentSpec) -> Bool {
        hasPhoto && (acceptedDocumentID == nil || acceptedDocumentID == spec.id)
    }

    /// Compatibility entry point for an already prepared image. New capture
    /// flows use acceptCrop so the full original survives later reframing.
    func adopt(_ image: UIImage, captureDate: Date? = nil, for spec: DocumentSpec? = nil) {
        guard let pixels = ImageBridge.cgImage(from: image) else { return }
        self.originalImage = image
        self.image = image
        self.cgImage = pixels
        self.captureDate = captureDate
        self.acceptedDocumentID = spec?.id
        self.cropTransform = .identity
        self.rotationQuarterTurns = 0
        invalidateDiagnosis()
    }

    /// Commits one reviewed crop. A malformed result cannot erase a previously
    /// accepted photo. Source and rotation are retained for a lossless re-edit.
    @discardableResult
    func acceptCrop(_ result: PreparedPhotoCrop, for spec: DocumentSpec, captureDate: Date?) -> Bool {
        guard let pixels = ImageBridge.cgImage(from: result.image),
              pixels.width > 0, pixels.height > 0,
              abs(Double(pixels.width) / Double(pixels.height) - spec.aspectRatio) < 0.02,
              ImageBridge.cgImage(from: result.originalImage) != nil else { return false }
        originalImage = result.originalImage
        image = result.image
        cgImage = pixels
        self.captureDate = captureDate
        acceptedDocumentID = spec.id
        cropTransform = result.transform
        rotationQuarterTurns = ((result.rotationQuarterTurns % 4) + 4) % 4
        invalidateDiagnosis()
        return true
    }

    func cropEditingContext(for spec: DocumentSpec) -> PhotoEditContext? {
        guard hasPhoto(for: spec), let originalImage else { return nil }
        return PhotoEditContext(
            id: revision,
            originalImage: originalImage,
            captureDate: captureDate,
            transform: cropTransform,
            rotationQuarterTurns: rotationQuarterTurns,
            documentID: spec.id
        )
    }

    @discardableResult
    func store(_ analysis: PhotoAnalysis, for documentID: String, revision expectedRevision: UUID? = nil) -> Bool {
        guard hasPhoto,
              acceptedDocumentID == nil || acceptedDocumentID == documentID,
              expectedRevision == nil || expectedRevision == revision else { return false }
        self.analysis = analysis
        self.analyzedDocumentID = documentID
        // A new diagnosis must never inherit a confirmation made against an
        // earlier set of findings. Updating the ordinary review does not rerun
        // analysis or change this separately labelled manual record.
        manualFraming = nil
        if acceptedDocumentID == nil { acceptedDocumentID = documentID }
        return true
    }

    func updateReview(_ review: PhotoReview) {
        self.review = review
        guard var analysis,
              let analyzedDocumentID,
              let spec = DocumentCorpus.document(id: analyzedDocumentID) else { return }
        analysis.update(review: review, spec: spec)
        self.analysis = analysis
    }

    /// Returns only a current, explicitly confirmed manual record. It does not
    /// turn missing automatic landmarks or quality signals into passing rules.
    func manualFraming(for spec: DocumentSpec) -> ManualFramingRecord? {
        guard hasPhoto(for: spec), analyzedDocumentID == spec.id,
              let analysis, analysis.geometry == nil, analysis.failures.isEmpty,
              let record = manualFraming,
              record.documentID == spec.id, record.revision == revision,
              record.review.allConfirmed,
              ManualFramingAssessment(guides: record.guides, spec: spec).isValid else { return nil }
        return record
    }

    @discardableResult
    func confirmManualFraming(
        guides: ManualFramingGuides,
        review: ManualFramingReview,
        for spec: DocumentSpec,
        revision expectedRevision: UUID
    ) -> Bool {
        guard hasPhoto(for: spec), analyzedDocumentID == spec.id,
              expectedRevision == revision,
              let analysis, analysis.geometry == nil,
              analysis.failures.isEmpty, review.allConfirmed,
              ManualFramingAssessment(guides: guides, spec: spec).isValid else { return false }
        manualFraming = ManualFramingRecord(guides: guides, review: review,
                                           documentID: spec.id, revision: revision)
        return true
    }

    func canExport(for spec: DocumentSpec) -> Bool {
        guard hasPhoto(for: spec),
              analyzedDocumentID == spec.id,
              review.allConfirmed,
              let analysis,
              analysis.failures.isEmpty else { return false }
        return analysis.geometry != nil || manualFraming(for: spec) != nil
    }

    func clear() {
        image = nil
        cgImage = nil
        originalImage = nil
        acceptedDocumentID = nil
        cropTransform = .identity
        rotationQuarterTurns = 0
        captureDate = nil
        layout = .fourBySix
        invalidateDiagnosis()
    }

    private func invalidateDiagnosis() {
        gate = nil
        analysis = nil
        analyzedDocumentID = nil
        manualFraming = nil
        review = .pending
        revision = UUID()
    }
}

// MARK: - UIImage to CGImage

enum ImageBridge {
    /// Every turn renders from the unmodified working original, never from an
    /// earlier rotated or accepted crop. Exact quarter turns preserve framing.
    static func rotatedImage(from original: CGImage, quarterTurns: Int) -> UIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        if turns == 0 { return UIImage(cgImage: original) }
        let sourceSize = CGSize(width: original.width, height: original.height)
        let outputSize = turns.isMultiple(of: 2)
            ? sourceSize
            : CGSize(width: original.height, height: original.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.rotate(by: CGFloat(turns) * .pi / 2)
            UIImage(cgImage: original).draw(in: CGRect(
                x: -sourceSize.width / 2, y: -sourceSize.height / 2,
                width: sourceSize.width, height: sourceSize.height
            ))
        }
    }

    /// Returns pixels with EXIF orientation baked in. `UIImage.cgImage` alone
    /// ignores `imageOrientation` and would rotate the validator's input.
    static func cgImage(from image: UIImage) -> CGImage? {
        if image.imageOrientation == .up, let cg = image.cgImage {
            return cg
        }
        guard image.size.width.isFinite, image.size.height.isFinite,
              image.size.width > 0, image.size.height > 0 else { return nil }

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
