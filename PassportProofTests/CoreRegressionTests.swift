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
}
