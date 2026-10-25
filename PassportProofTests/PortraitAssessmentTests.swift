import XCTest
import UIKit
@testable import PassportProof

/// Assessment evidence from photographic issuer examples, not an accuracy
/// benchmark. Some reference images are smaller than the required export size;
/// their complete verdict is recorded rather than assumed to be a global pass.
final class PortraitAssessmentTests: XCTestCase {
    func testOfficialPortraitsRecordRealVisionAndPreparedCropFindings() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "us-visa"))

        for name in ["NeutralPortrait", "BlueBackgroundPortrait", "WhiteBackgroundPortrait"] {
            let source = try fixture(named: name)
            let sourceGeometry = FaceAnalyzer.geometry(of: source)
            let original = ValidationEngine.analyze(image: source, spec: spec)
            record(name: "\(name)-original", image: source, analysis: original)
            XCTAssertNotNil(sourceGeometry, "Vision should find the portrait in \(name)")
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
        let source = try fixture(named: "NeutralPortrait")
        let padded = try whiteCanvas(around: source)
        let geometry = try XCTUnwrap(FaceAnalyzer.geometry(of: padded), "The padded real portrait must remain detectable")
        let transform = PhotoCrop.automaticTransform(for: padded, spec: spec)
        let rect = PhotoCrop.cropRect(
            imageSize: CGSize(width: padded.width, height: padded.height),
            spec: spec,
            transform: transform,
            integral: false
        )
        let cropped = try XCTUnwrap(PhotoCrop.croppedCGImage(from: padded, transform: transform, spec: spec))
        let prepared = ValidationEngine.analyze(image: cropped, spec: spec)

        // Preserve the detected source landmark through the actual crop rect.
        // Re-detection on the crop is reported separately and is not substituted
        // for this geometric check, which would conceal a crop-placement bug.
        let sourceEyePixelY = geometry.eyeY * Double(padded.height)
        let eyeFromTop = (sourceEyePixelY - Double(rect.minY)) / Double(rect.height)
        let eyeFromBottomMM = (1 - eyeFromTop) * spec.heightMM
        let context = "source=\(padded.width)x\(padded.height) cropRect=\(rect) zoom=\(transform.zoom) "
            + "sourceEyeY=\(geometry.eyeY) mappedEyeFromBottomMM=\(eyeFromBottomMM) "
            + "requiredMM=\(required.lowerBound)...\(required.upperBound) "
            + "redetectedEyeFromBottomMM=\(prepared.geometry.map { (1 - $0.eyeY) * spec.heightMM } as Any)"
        record(name: "padded-neutral-source", image: padded, analysis: ValidationEngine.analyze(image: padded, spec: spec))
        record(name: "padded-neutral-automatic-crop", image: cropped, analysis: prepared, context: context)

        // White padding is three times the source width/height, with no scaling
        // of the face. These assertions ensure source-edge clamping cannot be
        // mistaken for the known automatic vertical-placement regression.
        XCTAssertGreaterThan(rect.minY, 0)
        XCTAssertLessThan(rect.maxY, CGFloat(padded.height))
        XCTAssertEqual(geometry.crownInferredY, 2 * geometry.eyeY - geometry.chinY, accuracy: 0.000_001)
        XCTAssertEqual(Double(rect.midY), sourceEyePixelY, accuracy: 1)
        assertAnalysisContract(prepared, image: cropped)

        let options = XCTExpectedFailure.Options()
        options.isStrict = true
        XCTExpectFailure(
            "Known assessment defect: automaticTransform centres the inferred head midpoint, which is the eye line, at half the crop height (25.4 mm); the visa workflow requires 28–35 mm from the bottom.",
            options: options
        ) {
            XCTAssertTrue(required.contains(eyeFromBottomMM), context)
        }
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
        XCTAssertNotNil(analysis.geometry, "A real face should remain measurable", file: file, line: line)
        XCTAssertEqual(analysis.imagePixelSize, CGSize(width: image.width, height: image.height), file: file, line: line)
        XCTAssertEqual(analysis.findings.map(\.id), RuleID.allCases, file: file, line: line)
        XCTAssertEqual(analysis.overall, ValidationEngine.overall(for: analysis.findings), file: file, line: line)
        XCTAssertEqual(analysis.review, .pending, file: file, line: line)
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
            context,
        ]
        if let geometry = analysis.geometry {
            lines.append("geometry eyeY=\(geometry.eyeY) chinY=\(geometry.chinY) inferredCrownY=\(geometry.crownInferredY) envelopeY=\(geometry.crownEnvelopeY) crownDivergence=\(geometry.crownDivergence)")
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
}
