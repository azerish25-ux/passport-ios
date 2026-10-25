//
//  PassportProofTests.swift
//  PassportProofTests
//
//  Deterministic logic, imaging and compiled-bundle checks.
//

import XCTest
import CoreGraphics
import ImageIO
@testable import PassportProof

final class PassportProofTests: XCTestCase {

    // MARK: - Corpus and output contracts

    func testCorpusContainsOnlyCompleteWorkflows() {
        XCTAssertEqual(DocumentCorpus.documents.map(\.id), ["us-passport", "us-visa", "us-dv-lottery"])
        XCTAssertEqual(DocumentCorpus.document(id: "us-passport")?.workflow, .printedPhoto)
        XCTAssertEqual(DocumentCorpus.document(id: "us-visa")?.workflow, .digitalPhoto)
        XCTAssertEqual(DocumentCorpus.document(id: "us-dv-lottery")?.workflow, .digitalPhoto)
        XCTAssertNil(DocumentCorpus.document(id: "uk-passport"))
    }

    func testDocumentRulesAreOutputSpecific() {
        let passport = DocumentCorpus.documents[0]
        XCTAssertEqual(passport.headHeightMM.lowerBound, 25, accuracy: 0.0001)
        XCTAssertEqual(passport.headHeightMM.upperBound, 35, accuracy: 0.0001)
        XCTAssertEqual(passport.maximumPhotoAgeMonths, 6)
        XCTAssertTrue(passport.supportsPrintSheet)
        XCTAssertFalse(passport.supportsDigitalExport)

        for document in DocumentCorpus.documents.dropFirst() {
            XCTAssertEqual(document.headHeightMM.lowerBound, 25.4, accuracy: 0.0001)
            XCTAssertEqual(document.headHeightMM.upperBound, 34.9, accuracy: 0.0001)
            XCTAssertEqual(document.headHeightShare?.lowerBound, 0.50)
            XCTAssertEqual(document.headHeightShare?.upperBound, 0.69)
            XCTAssertEqual(document.maximumFileSizeBytes, 240_000)
            XCTAssertNotEqual(document.headHeightMM.lowerBound, 22)
        }
    }

    // MARK: - Shared crop geometry

    func testCropIsAspectLockedAndClampedInsideSource() {
        let image = makeImage(width: 1200, height: 900)
        let spec = DocumentCorpus.documents[0]
        let identityRect = PhotoCrop.cropRect(
            imageSize: CGSize(width: 1200, height: 900),
            spec: spec,
            transform: .identity
        )
        XCTAssertEqual(identityRect.width, 900, accuracy: 1)
        XCTAssertEqual(identityRect.height, 900, accuracy: 1)
        XCTAssertEqual(identityRect.midX, 600, accuracy: 1)

        let requested = CropTransform(zoom: 8, center: CGPoint(x: -1, y: 2))
        let clamped = PhotoCrop.clamped(
            requested,
            imageSize: CGSize(width: 1200, height: 900),
            spec: spec
        )
        XCTAssertEqual(clamped.zoom, PhotoCrop.zoomRange.upperBound)
        let rect = PhotoCrop.cropRect(
            imageSize: CGSize(width: 1200, height: 900),
            spec: spec,
            transform: clamped
        )
        XCTAssertGreaterThanOrEqual(rect.minX, 0)
        XCTAssertGreaterThanOrEqual(rect.minY, 0)
        XCTAssertLessThanOrEqual(rect.maxX, 1200)
        XCTAssertLessThanOrEqual(rect.maxY, 900)
    }

    func testPreparedCropIsWhatDigitalExportConsumes() {
        let source = makeImage(width: 1200, height: 900)
        let spec = DocumentCorpus.documents[0]
        guard let crop = PhotoCrop.croppedCGImage(from: source, transform: .identity, spec: spec) else {
            return XCTFail("crop failed")
        }
        XCTAssertEqual(crop.width, 900)
        XCTAssertEqual(crop.height, 900)
        XCTAssertNotNil(DigitalExport.jpegData(from: crop, spec: spec))

        // The original 4:3 source is not silently centre-cropped by the exporter.
        XCTAssertNil(DigitalExport.jpegData(from: source, spec: spec))
        XCTAssertNil(PrintSheetRenderer.pdfData(photo: source, layout: .fourBySix, spec: spec))
    }

    // MARK: - Digital export

    func testDigitalExportWritesDPIAndExactGeometry() {
        let image = makeImage(width: 900, height: 900)
        let spec = DocumentCorpus.documents[0]
        guard let data = DigitalExport.jpegData(from: image, spec: spec) else {
            return XCTFail("jpegData returned nil")
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let raw = CGImageSourceCopyPropertiesAtIndex(source, 0, nil),
              let properties = raw as? [String: Any],
              let exported = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return XCTFail("exported JPEG is not readable")
        }
        XCTAssertEqual((properties[kCGImagePropertyDPIWidth as String] as? NSNumber)?.intValue, 300)
        XCTAssertEqual((properties[kCGImagePropertyDPIHeight as String] as? NSNumber)?.intValue, 300)
        XCTAssertEqual(exported.width, spec.widthPixels)
        XCTAssertEqual(exported.height, spec.heightPixels)
    }

    func testDigitalExportHonoursIssuerByteCeilingOnDetailedImage() {
        let image = makeNoisyImage(width: 900, height: 900)
        let spec = DocumentCorpus.documents[1]
        guard let maximum = spec.maximumFileSizeBytes,
              let data = DigitalExport.jpegData(from: image, spec: spec) else {
            return XCTFail("detailed digital export failed")
        }
        XCTAssertLessThanOrEqual(data.count, maximum)
        XCTAssertGreaterThan(data.count, 1_000)
    }

    // MARK: - Print geometry

    func testPrintLayoutsAndPDF() {
        XCTAssertEqual(PrintSheetLayout.fourBySix.pageSizePoints, CGSize(width: 288, height: 432))
        XCTAssertEqual(PrintSheetLayout.fourBySix.columns, 2)
        XCTAssertEqual(PrintSheetLayout.fourBySix.rows, 2)
        XCTAssertEqual(PrintSheetLayout.letter12.pageSizePoints, CGSize(width: 612, height: 792))
        XCTAssertTrue(PrintSheetLayout.letter12.supportsCutMarks)

        let image = makeImage(width: 900, height: 900)
        let spec = DocumentCorpus.documents[0]
        guard let data = PrintSheetRenderer.pdfData(photo: image, layout: .fourBySix, spec: spec) else {
            return XCTFail("PDF rendering failed")
        }
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
        XCTAssertNotNil(PrintSheetRenderer.calibrationPDFData(layout: .fourBySix))
        XCTAssertNotNil(PrintSheetRenderer.calibrationPDFData(layout: .letter12))
        XCTAssertNil(PrintSheetRenderer.pdfData(photo: image, layout: .fourBySix, spec: DocumentCorpus.documents[1]))
    }

    // MARK: - Applicable findings and crown consistency

    func testOnlyApplicableRulesAreEmitted() {
        let passport = findings(spec: DocumentCorpus.documents[0])
        XCTAssertEqual(passport.count, 9)
        XCTAssertFalse(passport.contains { $0.id == .headHeightShare })
        XCTAssertFalse(passport.contains { $0.id == .eyeLine })

        let visa = findings(spec: DocumentCorpus.documents[1])
        XCTAssertEqual(visa.map(\.id), RuleID.allCases)
        XCTAssertEqual(visa.count, 11)
    }

    func testDivergingCrownCannotContradictItselfAcrossRules() {
        let spec = DocumentCorpus.documents[1]
        let geometry = makeGeometry(diverging: true)
        let results = findings(spec: spec, geometry: geometry)
        for id in [RuleID.headHeight, .headHeightShare, .eyeLine] {
            XCTAssertEqual(results.first { $0.id == id }?.status, .cannotVerify, id.rawValue)
        }
    }

    func testAgreeingCrownCanPassHeadHeight() {
        let result = findings(spec: DocumentCorpus.documents[0], geometry: makeGeometry())
        XCTAssertEqual(result.first { $0.id == .headHeight }?.status, .pass)
    }

    // MARK: - Visual review

    func testVisualChecksDoNotPassWithoutConfirmation() {
        let results = findings(spec: DocumentCorpus.documents[0], geometry: makeGeometry())
        XCTAssertEqual(results.first { $0.id == .expression }?.status, .cannotVerify)
        XCTAssertEqual(results.first { $0.id == .glasses }?.status, .cannotVerify)
        XCTAssertEqual(results.first { $0.id == .noManipulation }?.status, .cannotVerify)
        XCTAssertEqual(results.first { $0.id == .photoAge }?.status, .cannotVerify)
    }

    func testVisualChecksUpdateCachedRuleLayer() {
        let spec = DocumentCorpus.documents[0]
        var analysis = ValidationEngine.analyze(
            image: makeImage(width: 900, height: 900),
            spec: spec,
            captureDate: nil,
            review: .pending
        )
        var review = PhotoReview()
        review.expressionConfirmed = true
        review.glassesConfirmed = true
        review.originalUneditedConfirmed = true
        review.recentPhotoConfirmed = true
        analysis.update(review: review, spec: spec)
        XCTAssertEqual(analysis.review, review)
        XCTAssertEqual(analysis.findings.first { $0.id == .photoAge }?.status, .pass)
        XCTAssertEqual(analysis.findings.first { $0.id == .noManipulation }?.status, .pass)
    }

    func testGlareCannotBeOverruledByABlindConfirmation() {
        var review = PhotoReview()
        review.glassesConfirmed = true
        let results = findings(
            spec: DocumentCorpus.documents[0],
            geometry: makeGeometry(),
            glareSuspected: true,
            review: review
        )
        XCTAssertEqual(results.first { $0.id == .glasses }?.status, .cannotVerify)
    }

    // MARK: - Resolution and photo age

    func testResolutionChecksPreparedCropAgainstOutput() {
        let spec = DocumentCorpus.documents[0]
        let failing = findings(spec: spec, pixelSize: CGSize(width: 450, height: 450))
        XCTAssertEqual(failing.first { $0.id == .resolution }?.status, .fail)
        let passing = findings(spec: spec, pixelSize: CGSize(width: 900, height: 900))
        XCTAssertEqual(passing.first { $0.id == .resolution }?.status, .pass)
    }

    func testPhotoAgeUsesFixedReferenceAndRejectsFutureDates() {
        let reference = date(year: 2026, month: 10, day: 24)
        let recent = date(year: 2026, month: 9, day: 1)
        let stale = date(year: 2026, month: 3, day: 1)
        let future = date(year: 2027, month: 1, day: 1)
        let spec = DocumentCorpus.documents[0]

        XCTAssertEqual(
            findings(spec: spec, captureDate: recent, referenceDate: reference).first { $0.id == .photoAge }?.status,
            .pass
        )
        XCTAssertEqual(
            findings(spec: spec, captureDate: stale, referenceDate: reference).first { $0.id == .photoAge }?.status,
            .fail
        )
        XCTAssertEqual(
            findings(spec: spec, captureDate: future, referenceDate: reference).first { $0.id == .photoAge }?.status,
            .cannotVerify
        )
    }

    // MARK: - Aggregation and formatting

    func testOverallAggregation() {
        let pass = makeFinding(id: .noManipulation, status: .pass)
        let review = makeFinding(id: .expression, status: .cannotVerify)
        let fail = makeFinding(id: .resolution, status: .fail)
        XCTAssertEqual(ValidationEngine.overall(for: [pass]), .pass)
        XCTAssertEqual(ValidationEngine.overall(for: [pass, review]), .cannotVerify)
        XCTAssertEqual(ValidationEngine.overall(for: [pass, review, fail]), .fail)
    }

    func testDisplayRangeFormatting() {
        let measurement = MeasurementFormat.millimetres(value: 27.4, lowerBound: 25.4, upperBound: 34.9)
        XCTAssertEqual(measurement.displayValue, "27.4 mm")
        XCTAssertEqual(measurement.displayRange, "25.4 – 34.9 mm")
        XCTAssertFalse(measurement.displayRange.contains("-"))
    }

    // MARK: - Capture gate

    func testCaptureGateRefusesFrameWithNoFace() {
        let result = CaptureGate.evaluate(frame: makeImage(width: 600, height: 600), spec: DocumentCorpus.documents[0])
        XCTAssertFalse(result.canCapture)
        XCTAssertFalse(result.message.isEmpty)
    }

    // MARK: - EXIF decode

    func testExifDateParsing() {
        guard let parsed = PhotoImporter.parseExifDate("2026:03:14 10:30:00") else {
            return XCTFail("valid EXIF date did not parse")
        }
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: parsed)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
        XCTAssertNil(PhotoImporter.parseExifDate("not a date"))
    }

    func testDecodeImageReadsExifAndRejectsBadData() {
        let image = makeImage(width: 64, height: 64)
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return XCTFail("could not create JPEG destination")
        }
        let exif: [CFString: Any] = [kCGImagePropertyExifDateTimeOriginal: "2026:03:14 10:30:00"]
        CGImageDestinationAddImage(destination, image, [kCGImagePropertyExifDictionary: exif] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        guard let decoded = PhotoImporter.decodeImage(from: data as Data) else {
            return XCTFail("valid JPEG did not decode")
        }
        XCTAssertNotNil(decoded.captureDate)
        XCTAssertNil(PhotoImporter.decodeImage(from: Data("not an image".utf8)))
    }

    // MARK: - Compiled App Store surface

    func testAppIconIsCompiledIntoTheBundle() {
        XCTAssertNotNil(Bundle.main.url(forResource: "AppIcon60x60@2x", withExtension: "png"))
        let info = Bundle.main.infoDictionary ?? [:]
        XCTAssertTrue(info["CFBundleIconName"] != nil || info["CFBundleIcons"] != nil)
    }

    func testPrivacyAndLaunchConfigurationAreBundled() {
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        XCTAssertNotNil(Bundle.main.infoDictionary?["UILaunchScreen"])
        let info = Bundle.main.infoDictionary
        XCTAssertFalse((info?["NSCameraUsageDescription"] as? String ?? "").isEmpty)
        XCTAssertFalse((info?["NSPhotoLibraryUsageDescription"] as? String ?? "").isEmpty)
    }

    func testReleaseVersionAndPromiseWords() {
        let info = Bundle.main.infoDictionary ?? [:]
        let marketing = info["CFBundleShortVersionString"] as? String ?? ""
        XCTAssertFalse(marketing.isEmpty)
        XCTAssertFalse(marketing.hasPrefix("0."))
        let banned = ["approved", "guaranteed", "official", "accepted", "government-approved"]
        for string in allStrings(in: info) {
            for word in banned {
                XCTAssertFalse(string.lowercased().contains(word), "\(word) found in Info.plist")
            }
        }
    }

    // MARK: - Helpers

    private func findings(
        spec: DocumentSpec,
        geometry: FaceGeometry? = nil,
        background: BackgroundReport? = nil,
        pixelSize: CGSize = CGSize(width: 1200, height: 1200),
        captureDate: Date? = nil,
        glareSuspected: Bool = false,
        review: PhotoReview = .pending,
        referenceDate: Date = Date()
    ) -> [Finding] {
        ValidationEngine.findings(
            geometry: geometry,
            background: background,
            spec: spec,
            imagePixelSize: pixelSize,
            captureDate: captureDate,
            glareSuspected: glareSuspected,
            review: review,
            referenceDate: referenceDate
        )
    }

    private func makeGeometry(diverging: Bool = false) -> FaceGeometry {
        FaceGeometry(
            chinY: 0.82,
            eyeY: 0.526,
            crownEnvelopeY: diverging ? 0.05 : 0.225,
            crownInferredY: 0.232,
            faceCenterX: 0.5,
            faceWidth: 0.4,
            faceBox: CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.55)
        )
    }

    private func makeFinding(id: RuleID, status: FindingStatus) -> Finding {
        Finding(id: id, title: id.rawValue, status: status, detail: "", measurement: nil, provenance: .source)
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private func allStrings(in value: Any) -> [String] {
        switch value {
        case let dict as [String: Any]: return dict.flatMap { [$0.key] + allStrings(in: $0.value) }
        case let array as [Any]: return array.flatMap { allStrings(in: $0) }
        case let string as String: return [string]
        default: return []
        }
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
        ) else { fatalError("could not create test context") }
        context.setFillColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { fatalError("could not create test image") }
        return image
    }

    private func makeNoisyImage(width: Int, height: Int) -> CGImage {
        var pixels = [UInt8](repeating: 255, count: width * height * 4)
        var state: UInt32 = 0x1234_5678
        for index in stride(from: 0, to: pixels.count, by: 4) {
            state = 1_664_525 &* state &+ 1_013_904_223
            pixels[index] = UInt8(truncatingIfNeeded: state >> 16)
            pixels[index + 1] = UInt8(truncatingIfNeeded: state >> 8)
            pixels[index + 2] = UInt8(truncatingIfNeeded: state)
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        return pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { fatalError("could not create noise context") }
            guard let image = context.makeImage() else { fatalError("could not create noise image") }
            return image
        }
    }
}
