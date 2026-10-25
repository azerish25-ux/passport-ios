import XCTest
import CoreGraphics
@testable import PassportProof

/// Assessment probes for the background rule, using controlled pixel fixtures.
/// These deliberately isolate background classification: the rectangular subject
/// region is supplied to the analyzer; this is not a successful Vision face test.
final class AssessmentDiagnosticsTests: XCTestCase {
    func testPlainWhiteBackgroundPassesPositiveControl() throws {
        let finding = try backgroundFinding(name: "white", red: 1, green: 1, blue: 1)
        XCTAssertEqual(finding.status, .pass, "A plain white background is the positive control.")
    }

    func testUniformSaturatedBlueBackgroundMustNotPass() throws {
        let finding = try backgroundFinding(name: "saturated-blue", red: 0, green: 0, blue: 1)
        XCTAssertEqual(finding.status, .fail, "A saturated blue background must be rejected.")
    }

    func testUniformDarkBackgroundMustNotPass() throws {
        let finding = try backgroundFinding(name: "dark-gray", red: 0.20, green: 0.20, blue: 0.20)
        XCTAssertEqual(finding.status, .fail, "A dark gray background must be rejected.")
    }

    func testOffWhiteBackgroundPassesPositiveControl() throws {
        let finding = try backgroundFinding(name: "off-white", red: 0.96, green: 0.94, blue: 0.90)
        XCTAssertEqual(finding.status, .pass)
    }

    func testLightBlueBackgroundMustNotPass() throws {
        let finding = try backgroundFinding(name: "light-blue", red: 0.78, green: 0.90, blue: 1)
        XCTAssertEqual(finding.status, .fail, "Brightness alone must not make a coloured background acceptable.")
    }

    func testBorderlineGrayBackgroundRequiresReview() throws {
        let finding = try backgroundFinding(name: "borderline-gray", red: 0.78, green: 0.78, blue: 0.78)
        XCTAssertEqual(finding.status, .cannotVerify, "Borderline lighting must be disclosed, not called definitely compliant or noncompliant.")
    }

    private func backgroundFinding(
        name: String,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat
    ) throws -> Finding {
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 256,
            height: 256,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: red, green: green, blue: blue, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 256, height: 256))
        // Integer-aligned and symmetric on both axes so coordinate orientation
        // and interpolation cannot manufacture a background edge in this probe.
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 80, y: 80, width: 96, height: 96))
        let image = try XCTUnwrap(context.makeImage())
        let faceBox = CGRect(x: 80.0 / 256, y: 80.0 / 256, width: 96.0 / 256, height: 96.0 / 256)
        let report = BackgroundAnalyzer.analyze(image, faceBox: faceBox)
        let color = try XCTUnwrap(report.color, "Background colour must actually be sampled.")
        let findings = ValidationEngine.findings(
            geometry: nil,
            background: report,
            spec: DocumentCorpus.documents[0],
            imagePixelSize: CGSize(width: image.width, height: image.height),
            captureDate: nil
        )
        let finding = try XCTUnwrap(findings.first { $0.id == .backgroundUniformity })
        print("ASSESSMENT background=\(name) status=\(finding.status.rawValue) sigma=\(report.uniformitySigma) edgeResidual=\(report.edgeResidualFraction) luminance=\(color.meanLuminance) chroma=\(color.meanChroma) whiteFraction=\(color.whiteFraction)")
        XCTAssertEqual(report.uniformitySigma, 0, accuracy: 0.000_001, "The fixture must have a uniform sampled background.")
        XCTAssertEqual(report.edgeResidualFraction, 0, accuracy: 0.000_001, "The subject must stay clear of the sampled background ring.")
        return finding
    }
}
