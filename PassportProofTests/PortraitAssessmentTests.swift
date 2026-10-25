import XCTest
import UIKit
import Vision
@testable import PassportProof

/// Assessment evidence from photographic issuer examples, not an accuracy
/// benchmark. Some reference images are smaller than the required export size;
/// their complete verdict is recorded rather than assumed to be a global pass.
final class PortraitAssessmentTests: XCTestCase {
    private let fixtureNames = ["FullResolutionPortrait", "NeutralPortrait", "BlueBackgroundPortrait", "WhiteBackgroundPortrait"]

    func testFullResolutionPortraitRetainsMeasuredEyesAndChin() throws {
        let source = try fixture(named: "FullResolutionPortrait")
        let analysis = ValidationEngine.analyze(image: source, spec: DocumentCorpus.documents[1])
        record(name: "full-resolution-landmark-regression", image: source, analysis: analysis)
        let geometry = try XCTUnwrap(analysis.geometry, "The full-resolution frontal portrait must provide face geometry; uncertain hair/skull should be reported separately.")
        XCTAssertGreaterThan(geometry.chinY, geometry.eyeY)
        XCTAssertGreaterThan(geometry.eyeY, 0)
        XCTAssertLessThanOrEqual(geometry.chinY, 1)
        XCTAssertNotNil(analysis.findings.first { $0.id == .eyeLine }?.measurement)
    }

    @MainActor
    func testOfficialPortraitsRecordRealVisionAndPreparedCropFindings() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        print("ASSESSMENT runtime iOS=\(UIDevice.current.systemVersion) operatingSystem=\(ProcessInfo.processInfo.operatingSystemVersionString)")

        for name in fixtureNames {
            let source = try fixture(named: name)
            let sourceGeometry = FaceAnalyzer.geometry(of: source)
            let original = ValidationEngine.analyze(image: source, spec: spec)
            record(name: "\(name)-original", image: source, analysis: original,
                   context: "separateFaceAnalyzerGeometry=\(sourceGeometry == nil ? "nil" : "present")")
            assertAnalysisContract(original, image: source)

            let transform = PhotoCrop.automaticTransform(for: source, spec: spec)
            let crop = try XCTUnwrap(PhotoCrop.croppedCGImage(from: source, transform: transform, spec: spec))
            let prepared = ValidationEngine.analyze(image: crop, spec: spec)
            record(
                name: "\(name)-automatic-crop",
                image: crop,
                analysis: prepared,
                context: "zoom=\(transform.zoom) center=\(transform.center)"
            )
            assertAnalysisContract(prepared, image: crop)
            XCTAssertEqual(Double(crop.width) / Double(crop.height), spec.aspectRatio, accuracy: 0.01)
        }
    }

    func testUnconstrainedAutomaticCropRespectsVisaEyeLine() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))
        let required = try XCTUnwrap(spec.eyeLineFromBottomMM)

        // The small illustrative copies are not guaranteed detector inputs. Try
        // the declared order; a rejected precondition is evidence, not a pass.
        for name in fixtureNames {
            let source = try fixture(named: name)
            let padded = try whiteCanvas(around: source)
            let geometry = FaceAnalyzer.geometry(of: padded)
            record(name: "\(name)-padded-source", image: padded,
                   analysis: ValidationEngine.analyze(image: padded, spec: spec),
                   context: "cropProbeFaceAnalyzerGeometry=\(geometry == nil ? "nil" : "present")")
            guard let geometry else {
                print("ASSESSMENT cropProbe rejected=\(name) reason=production-face-geometry-unavailable")
                continue
            }
            let transform = PhotoCrop.automaticTransform(for: padded, spec: spec)
            let rect = PhotoCrop.cropRect(
                imageSize: CGSize(width: padded.width, height: padded.height),
                spec: spec,
                transform: transform,
                integral: false
            )
            let sourceEyePixelY = geometry.eyeY * Double(padded.height)
            guard rect.minY > 0, rect.maxY < CGFloat(padded.height) else {
                print("ASSESSMENT cropProbe rejected=\(name) reason=unconstrained-placement-precondition-not-established cropRect=\(rect) sourceEyePixelY=\(sourceEyePixelY) zoom=\(transform.zoom)")
                continue
            }
            let cropped = try XCTUnwrap(PhotoCrop.croppedCGImage(from: padded, transform: transform, spec: spec))
            let prepared = ValidationEngine.analyze(image: cropped, spec: spec)

            // Map the original landmark through the real crop. Re-detection is
            // reported independently; it must not conceal a placement error.
            let eyeFromTop = (sourceEyePixelY - Double(rect.minY)) / Double(rect.height)
            let eyeFromBottomMM = (1 - eyeFromTop) * spec.heightMM
            let context = "selectedFixture=\(name) source=\(padded.width)x\(padded.height) cropRect=\(rect) zoom=\(transform.zoom) "
                + "sourceEyeY=\(geometry.eyeY) mappedEyeFromBottomMM=\(eyeFromBottomMM) "
                + "cropCenterMinusSourceEyePX=\(Double(rect.midY) - sourceEyePixelY) "
                + "requiredMM=\(required.lowerBound)...\(required.upperBound) "
                + "redetectedEyeFromBottomMM=\(prepared.geometry.map { (1 - $0.eyeY) * spec.heightMM } as Any)"
            record(name: "\(name)-padded-automatic-crop", image: cropped, analysis: prepared, context: context)
            XCTAssertGreaterThan(rect.minY, 0)
            XCTAssertLessThan(rect.maxY, CGFloat(padded.height))
            assertAnalysisContract(prepared, image: cropped)

            XCTAssertTrue(required.contains(eyeFromBottomMM), context)
            return
        }
        XCTFail("No portrait established measurable, unconstrained source geometry, including the full-resolution fixture. The photographic crop regression was not exercised.")
    }

    private func fixture(named name: String) throws -> CGImage {
        let image = try XCTUnwrap(UIImage(named: name, in: Bundle(for: Self.self), compatibleWith: nil), "Missing assessment asset: \(name)")
        return try XCTUnwrap(ImageBridge.cgImage(from: image), "Could not decode assessment asset: \(name)")
    }

    private func whiteCanvas(around source: CGImage) throws -> CGImage {
        let width = source.width
        let height = source.height
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let size = CGSize(width: width * 3, height: height * 3)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIImage(cgImage: source).draw(in: CGRect(x: width, y: height, width: width, height: height))
        }
        return try XCTUnwrap(image.cgImage)
    }

    private func assertAnalysisContract(_ analysis: PhotoAnalysis, image: CGImage, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(analysis.imagePixelSize, CGSize(width: image.width, height: image.height), file: file, line: line)
        XCTAssertEqual(analysis.findings.map(\.id), RuleID.allCases, file: file, line: line)
        XCTAssertEqual(analysis.overall, ValidationEngine.overall(for: analysis.findings), file: file, line: line)
        XCTAssertEqual(analysis.review, .pending, file: file, line: line)
        if analysis.geometry == nil {
            XCTAssertNil(analysis.background, file: file, line: line)
            for id in [RuleID.headHeight, .headHeightShare, .eyeLine, .centring, .backgroundUniformity] {
                XCTAssertEqual(analysis.findings.first { $0.id == id }?.status, .cannotVerify,
                               "Missing geometry must not become a confident measurement: \(id.rawValue)", file: file, line: line)
            }
        }
        for finding in analysis.findings {
            if let measurement = finding.measurement {
                XCTAssertTrue(measurement.value.isFinite, "Non-finite measurement: \(finding.id.rawValue)", file: file, line: line)
            }
        }
    }

    private func record(name: String, image: CGImage, analysis: PhotoAnalysis, context: String = "") {
        var lines = [
            "ASSESSMENT portrait=\(name) size=\(image.width)x\(image.height) overall=\(analysis.overall.rawValue)",
            "Photographic diagnostic only; reference image resolution may fail. No accuracy or issuer-acceptance claim.",
            rawVisionSummary(image: image),
            context,
        ]
        if let geometry = analysis.geometry {
            lines.append("geometry eyeY=\(geometry.eyeY) chinY=\(geometry.chinY) inferredCrownY=\(geometry.crownInferredY) envelopeY=\(geometry.crownEnvelopeY) crownDivergence=\(geometry.crownDivergence) hasCrownSilhouette=\(geometry.hasCrownSilhouette)")
        } else {
            lines.append("geometry=nil")
        }
        if let background = analysis.background {
            lines.append("background sigma=\(background.uniformitySigma) crownContrast=\(background.crownContrast) edgeResidual=\(background.edgeResidualFraction)")
        }
        lines += analysis.findings.map { finding in
            let measurement = finding.measurement.map { "value=\($0.value) unit=\($0.unit) required=\($0.displayRange)" } ?? "unmeasured"
            return "\(finding.id.rawValue)=\(finding.status.rawValue) \(measurement) detail=\(finding.detail)"
        }
        let summary = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        print(summary)
        let textAttachment = XCTAttachment(string: summary)
        textAttachment.name = "\(name)-findings"
        textAttachment.lifetime = .keepAlways
        add(textAttachment)
        let imageAttachment = XCTAttachment(image: UIImage(cgImage: image))
        imageAttachment.name = name
        imageAttachment.lifetime = .keepAlways
        add(imageAttachment)
    }

    private func rawVisionSummary(image: CGImage) -> String {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        do {
            try handler.perform([request])
            let faces = request.results ?? []
            var summary = "rawVisionLandmarkFaceCount=\(faces.count) facesWithLandmarks=\(faces.filter { $0.landmarks != nil }.count) (separate diagnostic request; app geometry may reject a detected face)"
            if let face = faces.first, let landmarks = face.landmarks {
                let eyePoints = (landmarks.leftEye?.normalizedPoints ?? []) + (landmarks.rightEye?.normalizedPoints ?? [])
                let mappedEyes = eyePoints.map { FaceAnalyzer.imagePoint(fromNormalizedFacePoint: $0, in: face.boundingBox) }
                let mappedChin = landmarks.faceContour?.normalizedPoints.map {
                    FaceAnalyzer.imagePoint(fromNormalizedFacePoint: $0, in: face.boundingBox).y
                }.max()
                let mappedEyeY: CGFloat? = mappedEyes.isEmpty ? nil : mappedEyes.map(\.y).reduce(0, +) / CGFloat(mappedEyes.count)
                summary += " box=\(face.boundingBox) mappedEyeY=\(mappedEyeY as Any) mappedChinY=\(mappedChin as Any)"
            }
            return summary
        } catch {
            return "rawVisionLandmarkError=\(error.localizedDescription)"
        }
    }
}
