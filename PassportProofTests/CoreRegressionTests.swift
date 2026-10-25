import XCTest
import CoreGraphics
import AVFoundation
@testable import PassportProof

final class CoreRegressionTests: XCTestCase {
    func testAutomaticCropPlacesVisaAndDVEyesInPublishedBand() throws {
        let imageSize = CGSize(width: 1200, height: 1600)
        let geometry = FaceGeometry(
            chinY: 0.60,
            eyeY: 0.40,
            crownEnvelopeY: 0.20,
            crownInferredY: 0.20,
            faceCenterX: 0.50,
            faceWidth: 0.25,
            faceBox: CGRect(x: 0.375, y: 0.30, width: 0.25, height: 0.30)
        )
        for id in ["us-visa", "us-dv-lottery"] {
            let spec = try XCTUnwrap(DocumentCorpus.document(id: id))
            let band = try XCTUnwrap(spec.eyeLineFromBottomMM)
            let transform = PhotoCrop.automaticTransform(imageSize: imageSize, geometry: geometry, spec: spec)
            let rect = PhotoCrop.cropRect(imageSize: imageSize, spec: spec, transform: transform, integral: false)
            XCTAssertGreaterThan(rect.minY, 0, "The placement experiment must be unconstrained.")
            XCTAssertLessThan(rect.maxY, imageSize.height)
            let eyeFromTop = (geometry.eyeY * Double(imageSize.height) - Double(rect.minY)) / Double(rect.height)
            let fromBottomMM = (1 - eyeFromTop) * spec.heightMM
            XCTAssertTrue(band.contains(fromBottomMM), "\(id) placed eyes at \(fromBottomMM) mm")
            XCTAssertEqual(fromBottomMM, (band.lowerBound + band.upperBound) / 2, accuracy: 0.001)
            let headShare = geometry.headHeight * Double(imageSize.height) / Double(rect.height)
            XCTAssertTrue(try XCTUnwrap(spec.headHeightShare).contains(headShare))
        }
    }

    func testAutomaticCropKeepsEdgeConstrainedPhotoInsideSource() {
        let size = CGSize(width: 600, height: 1000)
        let geometry = FaceGeometry(
            chinY: 0.20, eyeY: 0.10, crownEnvelopeY: 0, crownInferredY: 0,
            faceCenterX: 0.05, faceWidth: 0.10,
            faceBox: CGRect(x: 0, y: 0.05, width: 0.10, height: 0.15)
        )
        let spec = DocumentCorpus.documents[1]
        let transform = PhotoCrop.automaticTransform(imageSize: size, geometry: geometry, spec: spec)
        let rect = PhotoCrop.cropRect(imageSize: size, spec: spec, transform: transform)
        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertGreaterThanOrEqual(rect.minY, 0)
        XCTAssertLessThanOrEqual(rect.maxX, size.width)
        XCTAssertLessThanOrEqual(rect.maxY, size.height)
    }

    func testCaptureSettingsNeverExceedOutputMaximum() {
        let output = AVCapturePhotoOutput()
        for maximum in [AVCapturePhotoOutput.QualityPrioritization.speed, .balanced, .quality] {
            output.maxPhotoQualityPrioritization = maximum
            let settings = CameraCaptureConfiguration.settings(for: output)
            XCTAssertEqual(settings.photoQualityPrioritization, maximum)
        }
    }

    func testFaceLandmarkMappingHasExplicitOriginAndBoxScale() {
        let box = CGRect(x: 0.20, y: 0.30, width: 0.40, height: 0.50)
        let eye = FaceAnalyzer.imagePoint(fromNormalizedFacePoint: CGPoint(x: 0.375, y: 0.70), in: box)
        let chin = FaceAnalyzer.imagePoint(fromNormalizedFacePoint: CGPoint(x: 0.50, y: 0.15), in: box)
        XCTAssertEqual(eye.x, 0.35, accuracy: 0.000_001)
        XCTAssertEqual(eye.y, 0.35, accuracy: 0.000_001)
        XCTAssertEqual(chin.x, 0.40, accuracy: 0.000_001)
        XCTAssertEqual(chin.y, 0.625, accuracy: 0.000_001)
        XCTAssertLessThan(eye.y, chin.y, "Top-origin eyes must remain above the chin.")
    }

    func testUncertainCrownDoesNotEraseMeasuredEyeLine() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let geometry = FaceGeometry(
            chinY: 0.65, eyeY: 0.38, crownEnvelopeY: 0.20, crownInferredY: 0.11,
            faceCenterX: 0.5, faceWidth: 0.30,
            faceBox: CGRect(x: 0.35, y: 0.25, width: 0.30, height: 0.40),
            hasCrownSilhouette: false
        )
        let results = ValidationEngine.findings(
            geometry: geometry, background: nil, spec: spec,
            imagePixelSize: CGSize(width: 1000, height: 1000), captureDate: nil
        )
        XCTAssertEqual(results.first { $0.id == .headHeight }?.status, .cannotVerify)
        XCTAssertEqual(results.first { $0.id == .headHeightShare }?.status, .cannotVerify)
        XCTAssertEqual(results.first { $0.id == .eyeLine }?.status, .pass)
        XCTAssertEqual(results.first { $0.id == .eyeLine }?.measurement?.value ?? 0,
                       0.62 * spec.heightMM, accuracy: 0.000_001)
    }

    func testVisaHeadHeightIncludesKnownHairOutline() throws {
        let geometry = FaceGeometry(
            chinY: 0.74, eyeY: 0.47, crownEnvelopeY: 0.14, crownInferredY: 0.20,
            faceCenterX: 0.50, faceWidth: 0.35,
            faceBox: CGRect(x: 0.325, y: 0.32, width: 0.35, height: 0.42)
        )
        let visa = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let results = ValidationEngine.findings(
            geometry: geometry, background: nil, spec: visa,
            imagePixelSize: CGSize(width: 1000, height: 1000), captureDate: nil
        )
        XCTAssertEqual(results.first { $0.id == .headHeight }?.status, .pass)
        XCTAssertEqual(results.first { $0.id == .headHeightShare }?.measurement?.value ?? 0, 60, accuracy: 0.001)
        XCTAssertEqual(geometry.headHeight(for: .skull), 0.54, accuracy: 0.001)
        XCTAssertEqual(geometry.headHeight(for: .includingHair), 0.60, accuracy: 0.001)
    }

    func testAmbiguousEdgeSignalCannotHideClearBackgroundFailures() throws {
        let white = BackgroundColorReport(meanLuminance: 0.95, meanChroma: 0.02, whiteFraction: 1, sampleCount: 1000)
        let blue = BackgroundColorReport(meanLuminance: 0.1, meanChroma: 1, whiteFraction: 0, sampleCount: 1000)
        let cases: [(String, BackgroundReport, FindingStatus)] = [
            ("edge only", BackgroundReport(uniformitySigma: 0.001, crownContrast: 0.5,
                                           edgeResidualFraction: 0.31, failingRegions: [], color: white), .cannotVerify),
            ("uneven background", BackgroundReport(uniformitySigma: 0.10, crownContrast: 0.5,
                                                   edgeResidualFraction: 0.31, failingRegions: [], color: white), .fail),
            ("coloured background", BackgroundReport(uniformitySigma: 0.001, crownContrast: 0.5,
                                                     edgeResidualFraction: 0.31, failingRegions: [], color: blue), .fail)
        ]
        for (name, report, expected) in cases {
            let results = ValidationEngine.findings(
                geometry: nil, background: report, spec: DocumentCorpus.documents[0],
                imagePixelSize: CGSize(width: 1000, height: 1000), captureDate: nil
            )
            let finding = try XCTUnwrap(results.first { $0.id == .backgroundUniformity })
            XCTAssertEqual(finding.status, expected, name)
        }
    }
}
