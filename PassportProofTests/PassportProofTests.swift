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

    // MARK: - Photo age (R7)

    func testPhotoAgePassesInsideSixMonthsAndFailsOutside() {
        let spec = DocumentCorpus.documents[0]
        let calendar = Calendar(identifier: .gregorian)

        let recent = calendar.date(byAdding: .month, value: -1, to: Date())
        let stale = calendar.date(byAdding: .month, value: -7, to: Date())

        let recentFindings = ValidationEngine.findings(
            geometry: nil,
            background: nil,
            spec: spec,
            imagePixelSize: CGSize(width: 1200, height: 1200),
            captureDate: recent
        )
        XCTAssertEqual(recentFindings.first { $0.id == .photoAge }?.status, .pass)

        let staleFindings = ValidationEngine.findings(
            geometry: nil,
            background: nil,
            spec: spec,
            imagePixelSize: CGSize(width: 1200, height: 1200),
            captureDate: stale
        )
        XCTAssertEqual(staleFindings.first { $0.id == .photoAge }?.status, .fail)
    }

    // MARK: - EXIF capture date

    func testExifDateParsing() {
        guard let parsed = PhotoImporter.parseExifDate("2026:03:14 10:30:00") else {
            return XCTFail("a well-formed EXIF date must parse")
        }

        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day, .hour, .minute], from: parsed
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)

        // A malformed date is unknown, never a guess.
        XCTAssertNil(PhotoImporter.parseExifDate("not a date"))
        XCTAssertNil(PhotoImporter.parseExifDate(""))
    }

    func testDecodeImageReadsExifCaptureDate() {
        // Encode a JPEG carrying EXIF DateTimeOriginal, then decode it back.
        let image = makeImage(width: 64, height: 64)
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data, "public.jpeg" as CFString, 1, nil
        ) else {
            return XCTFail("could not create the test destination")
        }

        let exif: [CFString: Any] = [kCGImagePropertyExifDateTimeOriginal: "2026:03:14 10:30:00"]
        let properties: [CFString: Any] = [kCGImagePropertyExifDictionary: exif]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return XCTFail("could not finalize the test JPEG")
        }

        guard let decoded = PhotoImporter.decodeImage(from: data as Data) else {
            return XCTFail("decodeImage returned nil for a valid JPEG")
        }
        guard let captureDate = decoded.captureDate else {
            return XCTFail("a JPEG carrying EXIF DateTimeOriginal must decode with a capture date")
        }
        let components = Calendar(identifier: .gregorian).dateComponents(
            [.year, .month, .day], from: captureDate
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
    }

    func testDecodeImageRejectsNonImageData() {
        XCTAssertNil(PhotoImporter.decodeImage(from: Data("not an image".utf8)))
    }

    // MARK: - App Store readiness (the bundle is the evidence)

    /// With a test host, `Bundle.main` is the compiled app bundle, so these
    /// assertions check what App Review would actually see.

    func testAppIconIsCompiledIntoTheBundle() {
        // actool injects CFBundleIconName when an app icon set is present and
        // non-empty. A missing or empty AppIcon fails this.
        let iconName = Bundle.main.infoDictionary?["CFBundleIconName"]
        XCTAssertNotNil(iconName, "CFBundleIconName is absent — the app icon did not compile into the bundle")
    }

    func testPrivacyManifestIsBundled() {
        let url = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
        XCTAssertNotNil(url, "PrivacyInfo.xcprivacy is not in the app bundle")
    }

    func testLaunchScreenIsConfigured() {
        let launchScreen = Bundle.main.infoDictionary?["UILaunchScreen"]
        XCTAssertNotNil(launchScreen, "UILaunchScreen is absent — the app has no launch screen configuration")
    }

    func testPrivacyUsageDescriptionsArePresent() {
        let info = Bundle.main.infoDictionary
        XCTAssertFalse(
            (info?["NSCameraUsageDescription"] as? String ?? "").isEmpty,
            "NSCameraUsageDescription is empty"
        )
        XCTAssertFalse(
            (info?["NSPhotoLibraryUsageDescription"] as? String ?? "").isEmpty,
            "NSPhotoLibraryUsageDescription is empty"
        )
    }

    func testBundleVersionIsAReleaseVersion() {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        guard let marketing, !marketing.isEmpty else {
            return XCTFail("CFBundleShortVersionString is absent or empty")
        }
        XCTAssertFalse(
            marketing.hasPrefix("0."),
            "a submission build must not carry a prototype version (found \(marketing))"
        )
    }

    /// AC5, applied to the compile-time surface: no promise word in the plist.
    func testInfoPlistCarriesNoBannedPromiseWords() {
        let banned = ["approved", "guaranteed", "official", "accepted", "government-approved"]
        let strings = allStrings(in: Bundle.main.infoDictionary ?? [:])
        for word in banned {
            for string in strings {
                XCTAssertFalse(
                    string.lowercased().contains(word),
                    "banned promise word “\(word)” appears in Info.plist"
                )
            }
        }
    }

    private func allStrings(in value: Any) -> [String] {
        switch value {
        case let dict as [String: Any]:
            return dict.flatMap { [$0.key] + allStrings(in: $0.value) }
        case let array as [Any]:
            return array.flatMap { allStrings(in: $0) }
        case let string as String:
            return [string]
        default:
            return []
        }
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
