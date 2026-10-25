import XCTest
import UIKit
import ImageIO
@testable import PassportProof

final class PhotoSessionTests: XCTestCase {
    @MainActor
    func testReeditKeepsOriginalAndCancellationDoesNotInvalidateAcceptedPhoto() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-passport"))
        let source = try makeImage(width: 1200, height: 900)
        let session = PhotoSession()
        let first = try prepared(source, spec: spec, zoom: 1.1)
        XCTAssertTrue(session.acceptCrop(first, for: spec, captureDate: Date()))
        makeReady(session, spec: spec)
        XCTAssertTrue(session.canExport(for: spec))
        let acceptedRevision = session.revision

        // Presenting and then discarding this snapshot is the editor's cancel
        // path: no source, accepted pixels or review state is mutated.
        let context = try XCTUnwrap(session.cropEditingContext(for: spec))
        XCTAssertEqual(context.originalImage.cgImage?.width, 1200)
        XCTAssertEqual(context.originalImage.cgImage?.height, 900)
        XCTAssertEqual(context.transform, first.transform)
        XCTAssertEqual(session.revision, acceptedRevision)
        XCTAssertTrue(session.review.allConfirmed)
        XCTAssertTrue(session.canExport(for: spec))

        let second = try prepared(source, spec: spec, zoom: 1.4)
        XCTAssertTrue(session.acceptCrop(second, for: spec, captureDate: context.captureDate))
        XCTAssertNotEqual(session.revision, acceptedRevision)
        XCTAssertEqual(session.originalImage?.cgImage?.width, 1200)
        XCTAssertEqual(session.originalImage?.cgImage?.height, 900)
        XCTAssertEqual(session.cropTransform, second.transform)
        XCTAssertNil(session.analysis)
        XCTAssertEqual(session.review, .pending)
        XCTAssertFalse(session.canExport(for: spec), "A new crop must be checked and confirmed again")
    }

    @MainActor
    func testWrongDocumentAndStaleAnalysisCannotReplaceCurrentCropReview() throws {
        let passport = try XCTUnwrap(DocumentCorpus.document(id: "us-passport"))
        let visa = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let source = try makeImage(width: 1200, height: 900)
        let session = PhotoSession()
        XCTAssertTrue(session.acceptCrop(try prepared(source, spec: passport, zoom: 1.1),
                                         for: passport, captureDate: Date()))
        makeReady(session, spec: passport)
        let oldAnalysis = try XCTUnwrap(session.analysis)
        let oldRevision = session.revision
        XCTAssertNil(session.cropEditingContext(for: visa))
        XCTAssertFalse(session.hasPhoto(for: visa))
        XCTAssertFalse(session.canExport(for: visa))

        XCTAssertTrue(session.acceptCrop(try prepared(source, spec: passport, zoom: 1.4),
                                         for: passport, captureDate: Date()))
        XCTAssertFalse(session.store(oldAnalysis, for: passport.id, revision: oldRevision),
                       "A late task from the previous crop must not publish its diagnosis")
        XCTAssertFalse(session.store(oldAnalysis, for: visa.id, revision: session.revision),
                       "A different workflow cannot take ownership of the accepted crop")
        XCTAssertNil(session.analysis)
        XCTAssertNil(session.analyzedDocumentID)
        XCTAssertEqual(session.review, .pending)
    }

    @MainActor
    func testInvalidReplacementKeepsAcceptedPhotoAndEraseClearsBothImages() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-passport"))
        let source = try makeImage(width: 1200, height: 900)
        let session = PhotoSession()
        XCTAssertTrue(session.acceptCrop(try prepared(source, spec: spec, zoom: 1.1), for: spec, captureDate: Date()))
        makeReady(session, spec: spec)
        let revision = session.revision
        let incorrectAspect = PreparedPhotoCrop(originalImage: UIImage(cgImage: source),
                                                image: UIImage(cgImage: source), transform: .identity,
                                                rotationQuarterTurns: 0)
        XCTAssertFalse(session.acceptCrop(incorrectAspect, for: spec, captureDate: nil))
        XCTAssertEqual(session.revision, revision)
        XCTAssertTrue(session.canExport(for: spec))

        session.clear()
        XCTAssertNil(session.image)
        XCTAssertNil(session.cgImage)
        XCTAssertNil(session.originalImage)
        XCTAssertNil(session.captureDate)
        XCTAssertNil(session.analysis)
        XCTAssertNil(session.acceptedDocumentID)
        XCTAssertNil(session.cropEditingContext(for: spec))
        XCTAssertEqual(session.review, .pending)
        XCTAssertFalse(session.canExport(for: spec))
    }

    func testImportedOrientationAndWorkingSizeRemainBoundedBeforeRotation() throws {
        let source = try makeImage(width: 4800, height: 1200)
        let encoded = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(encoded, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, source, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let decoded = try XCTUnwrap(PhotoImporter.decodeImage(from: encoded as Data))
        let pixels = try XCTUnwrap(decoded.image.cgImage)
        XCTAssertEqual(decoded.image.imageOrientation, .up)
        XCTAssertEqual(pixels.width, 1024)
        XCTAssertEqual(pixels.height, 4096)

        let rotated = ImageBridge.rotatedImage(from: pixels, quarterTurns: 1)
        XCTAssertEqual(rotated.cgImage?.width, 4096)
        XCTAssertEqual(rotated.cgImage?.height, 1024)
        let reopenedOriginal = ImageBridge.rotatedImage(from: pixels, quarterTurns: 0)
        XCTAssertEqual(reopenedOriginal.cgImage?.width, 1024)
        XCTAssertEqual(reopenedOriginal.cgImage?.height, 4096)
    }

    @MainActor
    func testManualFramingRetainsUnavailableAutomaticFindingsAndRequiresBothReviews() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let session = PhotoSession()
        session.adopt(UIImage(cgImage: try makeImage(width: 900, height: 900)), for: spec)
        storeUnavailableMeasurements(session, spec: spec)
        let unresolved = try XCTUnwrap(session.analysis).unresolved.map(\.id)
        let guides = ManualFramingGuides(topY: 0.10, chinY: 0.70, eyeY: 0.38, centerX: 0.5)
        XCTAssertFalse(session.canExport(for: spec))
        XCTAssertFalse(session.confirmManualFraming(guides: guides, review: .pending,
                                                   for: spec, revision: session.revision))
        XCTAssertNil(session.manualFraming)
        XCTAssertTrue(session.confirmManualFraming(guides: guides, review: confirmedManualReview,
                                                  for: spec, revision: session.revision))
        XCTAssertFalse(session.canExport(for: spec), "The ordinary four visual confirmations are still required")

        session.updateReview(PhotoReview(expressionConfirmed: true, glassesConfirmed: true,
                                         originalUneditedConfirmed: true, recentPhotoConfirmed: true))
        XCTAssertTrue(session.canExport(for: spec))
        XCTAssertNil(session.analysis?.geometry, "Manual guides must never masquerade as detected landmarks")
        let currentUnresolved = try XCTUnwrap(session.analysis).unresolved.map(\.id)
        for id in unresolved where ![RuleID.expression, .glasses, .photoAge, .noManipulation].contains(id) {
            XCTAssertTrue(currentUnresolved.contains(id), "Missing automatic signals must stay unresolved")
        }
        XCTAssertNotNil(session.manualFraming(for: spec))
        let passport = try XCTUnwrap(DocumentCorpus.document(id: "us-passport"))
        XCTAssertNil(session.manualFraming(for: passport))
        XCTAssertFalse(session.canExport(for: passport))
    }

    @MainActor
    func testManualFramingCannotOverrideFailedResolutionOrInvalidGuides() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let session = PhotoSession()
        let guides = ManualFramingGuides(topY: 0.10, chinY: 0.70, eyeY: 0.38, centerX: 0.5)
        session.adopt(UIImage(cgImage: try makeImage(width: 120, height: 120)), for: spec)
        storeUnavailableMeasurements(session, spec: spec)
        XCTAssertTrue(session.analysis?.failures.contains(where: { $0.id == .resolution }) == true)
        XCTAssertFalse(session.confirmManualFraming(guides: guides, review: confirmedManualReview,
                                                   for: spec, revision: session.revision))
        XCTAssertFalse(session.canExport(for: spec))

        session.adopt(UIImage(cgImage: try makeImage(width: 900, height: 900)), for: spec)
        storeUnavailableMeasurements(session, spec: spec)
        let outsideFrame = ManualFramingGuides(topY: -0.1, chinY: 0.70, eyeY: 0.38, centerX: 0.5)
        XCTAssertFalse(session.confirmManualFraming(guides: outsideFrame, review: confirmedManualReview,
                                                   for: spec, revision: session.revision))
        XCTAssertNil(session.manualFraming)
    }

    @MainActor
    func testManualFramingCancellationPreservesRecordAndNewCropRejectsStaleConfirmation() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let source = try makeImage(width: 1200, height: 1200)
        let session = PhotoSession()
        XCTAssertTrue(session.acceptCrop(try prepared(source, spec: spec, zoom: 1), for: spec, captureDate: nil))
        storeUnavailableMeasurements(session, spec: spec)
        let guides = ManualFramingGuides(topY: 0.10, chinY: 0.70, eyeY: 0.38, centerX: 0.5)
        let oldRevision = session.revision
        XCTAssertTrue(session.confirmManualFraming(guides: guides, review: confirmedManualReview,
                                                  for: spec, revision: oldRevision))
        let record = try XCTUnwrap(session.manualFraming(for: spec))
        _ = try XCTUnwrap(session.cropEditingContext(for: spec))
        // Editors change local drafts. Discarding either editor must preserve
        // the accepted record; no confirmation is written until Save.
        XCTAssertEqual(session.manualFraming(for: spec), record)
        XCTAssertEqual(session.revision, oldRevision)

        XCTAssertTrue(session.acceptCrop(try prepared(source, spec: spec, zoom: 1.2), for: spec, captureDate: nil))
        XCTAssertNil(session.manualFraming)
        XCTAssertEqual(session.review, .pending)
        storeUnavailableMeasurements(session, spec: spec)
        XCTAssertFalse(session.confirmManualFraming(guides: guides, review: confirmedManualReview,
                                                   for: spec, revision: oldRevision))
        XCTAssertFalse(session.canExport(for: spec))
        XCTAssertTrue(session.confirmManualFraming(guides: guides, review: confirmedManualReview,
                                                  for: spec, revision: session.revision))
        session.clear()
        XCTAssertNil(session.manualFraming)
        XCTAssertNil(session.manualFraming(for: spec))
    }

    @MainActor
    func testNewDiagnosisInvalidatesPreviousManualApproval() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let session = PhotoSession()
        session.adopt(UIImage(cgImage: try makeImage(width: 900, height: 900)), for: spec)
        storeUnavailableMeasurements(session, spec: spec)
        let guides = ManualFramingGuides(topY: 0.10, chinY: 0.70, eyeY: 0.38, centerX: 0.5)
        XCTAssertTrue(session.confirmManualFraming(guides: guides, review: confirmedManualReview,
                                                  for: spec, revision: session.revision))
        storeUnavailableMeasurements(session, spec: spec)
        XCTAssertNil(session.manualFraming)
        XCTAssertFalse(session.canExport(for: spec))
    }

    private var confirmedManualReview: ManualFramingReview {
        ManualFramingReview(guidesConfirmed: true, singleFaceAndPoseConfirmed: true,
                            backgroundAndLightingConfirmed: true, limitationsAccepted: true)
    }

    /// Isolates the manual approval state machine using the real rule layer.
    /// No geometry is supplied and every unavailable measurement stays nil.
    @MainActor
    private func storeUnavailableMeasurements(_ session: PhotoSession, spec: DocumentSpec) {
        let pixels = CGSize(width: session.cgImage?.width ?? 0, height: session.cgImage?.height ?? 0)
        let findings = ValidationEngine.findings(geometry: nil, background: nil, spec: spec,
                                                 imagePixelSize: pixels, captureDate: nil)
        let analysis = PhotoAnalysis(findings: findings, geometry: nil, background: nil,
                                     overall: ValidationEngine.overall(for: findings), imagePixelSize: pixels,
                                     captureDate: nil, shadowDelta: nil, glareSuspected: false, review: .pending)
        XCTAssertTrue(session.store(analysis, for: spec.id, revision: session.revision))
    }

    private func prepared(_ source: CGImage, spec: DocumentSpec, zoom: CGFloat) throws -> PreparedPhotoCrop {
        let transform = CropTransform(zoom: zoom, center: CGPoint(x: 0.5, y: 0.5))
        let crop = try XCTUnwrap(PhotoCrop.croppedCGImage(from: source, transform: transform, spec: spec))
        return PreparedPhotoCrop(originalImage: UIImage(cgImage: source), image: UIImage(cgImage: crop),
                                 transform: transform, rotationQuarterTurns: 0)
    }

    /// Known geometry isolates the session state machine. This fixture makes no
    /// claim about face detection or whether a photograph will be accepted.
    @MainActor
    private func makeReady(_ session: PhotoSession, spec: DocumentSpec) {
        let geometry = FaceGeometry(chinY: 0.82, eyeY: 0.526, crownEnvelopeY: 0.225,
                                    crownInferredY: 0.232, faceCenterX: 0.5, faceWidth: 0.4,
                                    faceBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.55))
        let pixels = CGSize(width: session.cgImage?.width ?? 0, height: session.cgImage?.height ?? 0)
        let findings = ValidationEngine.findings(geometry: geometry, background: nil, spec: spec,
                                                 imagePixelSize: pixels, captureDate: session.captureDate)
        let analysis = PhotoAnalysis(findings: findings, geometry: geometry, background: nil,
                                     overall: ValidationEngine.overall(for: findings), imagePixelSize: pixels,
                                     captureDate: session.captureDate, shadowDelta: nil, glareSuspected: false,
                                     review: .pending)
        XCTAssertTrue(session.store(analysis, for: spec.id, revision: session.revision))
        session.updateReview(PhotoReview(expressionConfirmed: true, glassesConfirmed: true,
                                         originalUneditedConfirmed: true, recentPhotoConfirmed: true))
    }

    private func makeImage(width: Int, height: Int) throws -> CGImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height,
                                              bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        context.setFillColor(red: 0.94, green: 0.94, blue: 0.91, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(red: 0.1, green: 0.3, blue: 0.25, alpha: 1)
        context.fill(CGRect(x: width / 4, y: height / 4, width: width / 4, height: height / 2))
        return try XCTUnwrap(context.makeImage())
    }
}
