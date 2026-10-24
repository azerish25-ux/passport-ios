//
//  PassportProofTests.swift
//  PassportProofTests
//
//  Deterministic tests only. Nothing here depends on Vision finding a face in a
//  synthetic image; the geometry tests build `FaceGeometry` by hand.
//

import XCTest
import CoreGraphics
import ImageIO
@testable import PassportProof

final class PassportProofTests: XCTestCase {

    // MARK: - Corpus

    func testCorpusHasFourDocumentsInContractOrder() {
        let documents = DocumentCorpus.documents
        XCTAssertEqual(documents.count, 4)
        XCTAssertEqual(
            documents.map(\.id),
            ["us-passport", "us-visa", "us-dv-2026", "uk-passport"]
        )
        XCTAssertEqual(DocumentCorpus.launchTargetCount, 12)
        XCTAssertEqual(DocumentCorpus.pendingDocumentNames.count, 8)
        XCTAssertEqual(documents.count + DocumentCorpus.pendingDocumentNames.count, DocumentCorpus.launchTargetCount)
    }

    func testHeadHeightLowerBounds() {
        let usDocuments = DocumentCorpus.documents.filter { $0.countryCode == "US" }
        XCTAssertEqual(usDocuments.count, 3)
        for document in usDocuments {
            XCTAssertEqual(document.headHeightMM.lowerBound, 25.4, accuracy: 0.0001, document.id)
            XCTAssertEqual(document.headHeightMM.upperBound, 34.9, accuracy: 0.0001, document.id)
        }

        guard let uk = DocumentCorpus.document(id: "uk-passport") else {
            return XCTFail("uk-passport missing from the corpus")
        }
        XCTAssertEqual(uk.headHeightMM.lowerBound, 29.0, accuracy: 0.0001)
        XCTAssertEqual(uk.headHeightMM.upperBound, 34.0, accuracy: 0.0001)
        XCTAssertEqual(uk.widthMM, 35)
        XCTAssertEqual(uk.heightMM, 45)
        XCTAssertEqual(uk.widthPixels, 413)
        XCTAssertEqual(uk.heightPixels, 531)
    }

    func testTheTwentyTwoMillimetreRuleAppearsNowhere() {
        XCTAssertTrue(DocumentCorpus.documents.allSatisfy { $0.headHeightMM.lowerBound != 22 })

        for document in DocumentCorpus.documents {
            XCTAssertFalse(
                MeasurementFormat.range(document.headHeightMM.lowerBound, document.headHeightMM.upperBound, unit: "mm").contains("22"),
                document.id
            )

            let text = [
                document.id,
                document.country,
                document.countryCode,
                document.documentName,
                document.backgroundDescription,
                document.sourceURL.absoluteString
            ].joined(separator: " ")
                + " " + document.changelog.map(\.note).joined(separator: " ")
                + " " + document.changelog.map(\.id).joined(separator: " ")

            XCTAssertFalse(text.contains("22"), "The 22 mm clause leaked into \(document.id)")
        }
    }

    // MARK: - Print geometry

    func testFourBySixIsFourUp() {
        let layout = PrintSheetLayout.fourBySix
        XCTAssertEqual(layout.pageSizePoints, CGSize(width: 288, height: 432))
        XCTAssertEqual(layout.columns, 2)
        XCTAssertEqual(layout.rows, 2)
        XCTAssertFalse(layout.supportsCutMarks)
    }

    func testLetterTwelveUp() {
        let layout = PrintSheetLayout.letter12
        XCTAssertEqual(layout.pageSizePoints, CGSize(width: 612, height: 792))
        XCTAssertEqual(layout.columns, 3)
        XCTAssertEqual(layout.rows, 4)
        XCTAssertTrue(layout.supportsCutMarks)
    }

    func testPDFRendersAndCarriesThePDFHeader() {
        let image = makeImage(width: 600, height: 600)
        let spec = DocumentCorpus.documents[0]

        guard let data = PrintSheetRenderer.pdfData(photo: image, layout: .fourBySix, spec: spec) else {
            return XCTFail("pdfData returned nil")
        }
        XCTAssertGreaterThan(data.count, 100)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))

        XCTAssertNotNil(PrintSheetRenderer.calibrationPDFData(layout: .fourBySix))
        XCTAssertNotNil(PrintSheetRenderer.calibrationPDFData(layout: .letter12))
    }

    // MARK: - Digital export

    func testDigitalExportWritesDPIAndPortalGeometry() {
        let image = makeImage(width: 1200, height: 1200)
        let spec = DocumentCorpus.documents[0]

        guard let data = DigitalExport.jpegData(from: image, spec: spec) else {
            return XCTFail("jpegData returned nil")
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return XCTFail("the exported data is not a readable image")
        }
        guard let rawProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
              let properties = rawProperties as? [String: Any] else {
            return XCTFail("no image properties")
        }

        let dpiWidth = (properties[kCGImagePropertyDPIWidth as String] as? NSNumber)?.intValue
        let dpiHeight = (properties[kCGImagePropertyDPIHeight as String] as? NSNumber)?.intValue
        XCTAssertEqual(dpiWidth ?? -1, 300)
        XCTAssertEqual(dpiHeight ?? -1, 300)

        guard let exported = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return XCTFail("the exported data has no image")
        }
        XCTAssertEqual(exported.width, spec.widthPixels)
        XCTAssertEqual(exported.height, spec.heightPixels)
    }

    // MARK: - Head height divergence

    func testDivergingCrownEstimatorsReportCannotVerify() {
        let spec = DocumentCorpus.documents[0] // 51 mm, 25.4–34.9 mm

        // 0.5882 × 51 mm ≈ 30 mm: comfortably inside the band.
        let agreeing = FaceGeometry(
            chinY: 0.82,
            eyeY: 0.526,
            crownEnvelopeY: 0.225,
            crownInferredY: 0.232,
            faceCenterX: 0.5,
            faceWidth: 0.4,
            faceBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.55)
        )

        let agreeingFinding = headHeightFinding(geometry: agreeing, spec: spec)
        XCTAssertNotEqual(agreeingFinding.status, .cannotVerify)
        XCTAssertEqual(agreeingFinding.status, .pass)

        // An updo: the silhouette sits far above the inferred crown.
        let diverging = FaceGeometry(
            chinY: 0.82,
            eyeY: 0.526,
            crownEnvelopeY: 0.05,
            crownInferredY: 0.232,
            faceCenterX: 0.5,
            faceWidth: 0.4,
            faceBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.55)
        )

        let divergingFinding = headHeightFinding(geometry: diverging, spec: spec)
        XCTAssertEqual(divergingFinding.status, .cannotVerify)
        XCTAssertGreaterThan(diverging.crownDivergence, ValidationEngine.crownDivergenceLimit)

        // A head too large for the band, with agreeing estimators, still fails.
        let tooLarge = FaceGeometry(
            chinY: 0.95,
            eyeY: 0.60,
            crownEnvelopeY: 0.10,
            crownInferredY: 0.105,
            faceCenterX: 0.5,
            faceWidth: 0.4,
            faceBox: CGRect(x: 0.3, y: 0.1, width: 0.4, height: 0.85)
        )
        XCTAssertEqual(headHeightFinding(geometry: tooLarge, spec: spec).status, .fail)
    }

    func testMissingFaceReportsCannotVerifyForHeadHeight() {
        let spec = DocumentCorpus.documents[0]
        let findings = ValidationEngine.findings(
            geometry: nil,
            background: nil,
            spec: spec,
            imagePixelSize: CGSize(width: 1200, height: 1200),
            captureDate: nil
        )
        let headHeight = findings.first { $0.id == .headHeight }
        XCTAssertEqual(headHeight?.status, .cannotVerify)
    }

    // MARK: - Aggregation

    func testOverallAggregation() {
        let pass = makeFinding(id: .noManipulation, status: .pass)
        let cannotVerify = makeFinding(id: .expression, status: .cannotVerify)
        let fail = makeFinding(id: .resolution, status: .fail)

        XCTAssertEqual(ValidationEngine.overall(for: [pass]), .pass)
        XCTAssertEqual(ValidationEngine.overall(for: [pass, cannotVerify]), .cannotVerify)
        XCTAssertEqual(ValidationEngine.overall(for: [pass, cannotVerify, fail]), .fail)
        XCTAssertEqual(ValidationEngine.overall(for: [fail, cannotVerify]), .fail)
    }

    // MARK: - Formatting

    func testDisplayRangeUsesAnEnDashAndTheUnit() {
        let measurement = MeasurementFormat.millimetres(value: 27.4, lowerBound: 25.4, upperBound: 34.9)
        XCTAssertTrue(measurement.displayRange.contains("–"))
        XCTAssertFalse(measurement.displayRange.contains("-"))
        XCTAssertTrue(measurement.displayRange.contains("mm"))
        XCTAssertEqual(measurement.displayValue, "27.4 mm")
        XCTAssertEqual(measurement.unit, "mm")
    }

    // MARK: - Rule order

    func testFindingsAreEmittedInContractOrder() {
        let spec = DocumentCorpus.documents[0]
        let findings = ValidationEngine.findings(
            geometry: nil,
            background: nil,
            spec: spec,
            imagePixelSize: CGSize(width: 1200, height: 1200),
            captureDate: nil
        )
        XCTAssertEqual(findings.map(\.id), RuleID.allCases)
        XCTAssertEqual(findings.count, 11)
        XCTAssertEqual(
            findings.map(\.id.rawValue),
            [
                "headHeight", "headHeightShare", "eyeLine", "centring",
                "backgroundUniformity", "shadow", "expression", "glasses",
                "resolution", "photoAge", "noManipulation"
            ]
        )
    }

    // MARK: - Capture gate

    func testCaptureGateRefusesAFrameWithNoFace() {
        let spec = DocumentCorpus.documents[0]
        let result = CaptureGate.evaluate(frame: makeImage(width: 600, height: 600), spec: spec)
        XCTAssertFalse(result.canCapture)
        XCTAssertFalse(result.message.isEmpty)
    }

    // MARK: - Helpers

    private func headHeightFinding(geometry: FaceGeometry, spec: DocumentSpec) -> Finding {
        let findings = ValidationEngine.findings(
            geometry: geometry,
            background: nil,
            spec: spec,
            imagePixelSize: CGSize(width: 1200, height: 1200),
            captureDate: nil
        )
        guard let finding = findings.first(where: { $0.id == .headHeight }) else {
            XCTFail("headHeight finding missing")
            return Finding(
                id: .headHeight,
                title: "Head height",
                status: .cannotVerify,
                detail: "",
                measurement: nil,
                provenance: .source
            )
        }
        return finding
    }

    private func makeFinding(id: RuleID, status: FindingStatus) -> Finding {
        Finding(
            id: id,
            title: id.rawValue,
            status: status,
            detail: "",
            measurement: nil,
            provenance: .source
        )
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("could not create a test bitmap context")
        }
        context.setFillColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else {
            fatalError("could not create a test image")
        }
        return image
    }
}
