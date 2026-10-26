//
//  CatalogueContractTests.swift
//  PassportProofTests
//
//  The catalogue is data, and data drifts silently. These tests make a wrong
//  entry fail the build instead of producing a plausible-looking photo that an
//  authority rejects: mismatched aspect ratios, a head range larger than the
//  photo, a missing source, or a print grid that would scale a photo.
//

import XCTest
import CoreGraphics
@testable import PassportProof

final class CatalogueContractTests: XCTestCase {

    func testEveryDocumentIsInternallyConsistent() throws {
        XCTAssertFalse(DocumentCorpus.documents.isEmpty)
        XCTAssertEqual(Set(DocumentCorpus.documents.map(\.id)).count, DocumentCorpus.documents.count,
                       "Document identifiers must be unique")

        let now = Date()
        for spec in DocumentCorpus.documents {
            let label = spec.id

            XCTAssertFalse(spec.documentName.isEmpty, label)
            XCTAssertFalse(spec.country.isEmpty, label)
            XCTAssertEqual(spec.countryCode.count, 2, label)

            // Physical and pixel geometry must describe the same shape, or the
            // crop the user approves cannot become the file they export.
            let physicalAspect = spec.widthMM / spec.heightMM
            let pixelAspect = Double(spec.widthPixels) / Double(spec.heightPixels)
            XCTAssertEqual(physicalAspect, pixelAspect, accuracy: 0.005,
                           "\(label): \(spec.widthMM)×\(spec.heightMM) mm is not \(spec.widthPixels)×\(spec.heightPixels) px")

            XCTAssertTrue(spec.widthMM > 0 && spec.heightMM > 0, label)
            // Print quality is a density, not a pixel count. A 35 × 45 mm photo
            // reaches 300 DPI at 420 × 540 px; requiring 600 px on both sides
            // would reject correct small-format media.
            let horizontalDPI = Double(spec.widthPixels) / (spec.widthMM / 25.4)
            let verticalDPI = Double(spec.heightPixels) / (spec.heightMM / 25.4)
            XCTAssertGreaterThanOrEqual(horizontalDPI, 299.5,
                                        "\(label): \(spec.widthPixels) px over \(spec.widthMM) mm is under 300 DPI")
            XCTAssertGreaterThanOrEqual(verticalDPI, 299.5,
                                        "\(label): \(spec.heightPixels) px over \(spec.heightMM) mm is under 300 DPI")

            XCTAssertGreaterThan(spec.headHeightMM.lowerBound, 0, label)
            XCTAssertLessThan(spec.headHeightMM.lowerBound, spec.headHeightMM.upperBound, label)
            XCTAssertLessThan(spec.headHeightMM.upperBound, spec.heightMM,
                              "\(label): a head range taller than the photo is unusable")

            if let share = spec.headHeightShare {
                XCTAssertGreaterThan(share.lowerBound, 0.2, label)
                XCTAssertLessThan(share.upperBound, 0.95, label)
                let midpointMM = (share.lowerBound + share.upperBound) / 2 * spec.heightMM
                let midpointHead = (spec.headHeightMM.lowerBound + spec.headHeightMM.upperBound) / 2
                XCTAssertEqual(midpointMM, midpointHead, accuracy: 0.6,
                               "\(label): the published share and the stated millimetres disagree")
            }

            if let eyeLine = spec.eyeLineFromBottomMM {
                XCTAssertGreaterThan(eyeLine.lowerBound, 0, label)
                XCTAssertLessThan(eyeLine.upperBound, spec.heightMM, label)
                XCTAssertLessThan(eyeLine.upperBound, spec.headHeightMM.upperBound + (spec.heightMM - spec.headHeightMM.lowerBound),
                                  "\(label): an eye line above the crown is impossible")
            }

            XCTAssertGreaterThan(spec.maximumPhotoAgeMonths, 0, label)
            XCTAssertLessThanOrEqual(spec.maximumPhotoAgeMonths, 6,
                                     "\(label): no supported issuer accepts an older photo")
            if let bytes = spec.maximumFileSizeBytes {
                XCTAssertGreaterThan(bytes, 0, label)
                XCTAssertEqual(spec.workflow, .digitalPhoto,
                               "\(label): a byte ceiling only applies to a digital upload")
            }
            if spec.workflow == .digitalPhoto {
                XCTAssertNotNil(spec.maximumFileSizeBytes, "\(label): digital uploads need a byte ceiling")
            }

            XCTAssertEqual(spec.sourceURL.scheme, "https", "\(label): the source must be an https URL")
            XCTAssertLessThanOrEqual(spec.verifiedOn, now, "\(label): a future verification date is not evidence")
            XCTAssertFalse(spec.changelog.isEmpty, "\(label): every workflow needs its provenance note")
            for entry in spec.changelog {
                XCTAssertEqual(entry.date, spec.verifiedOn, "\(label): changelog dates must match verification")
                XCTAssertFalse(entry.note.isEmpty, label)
            }

            XCTAssertFalse(spec.backgroundDescription.isEmpty, label)
            XCTAssertFalse(spec.expressionRequirement.isEmpty, label)
            XCTAssertFalse(spec.glassesRequirement.isEmpty, label)
        }
    }

    func testCatalogueGroupingCoversEveryDocumentOnce() {
        let grouped = DocumentCorpus.countries.flatMap(\.documents)
        XCTAssertEqual(grouped.count, DocumentCorpus.documents.count)
        XCTAssertEqual(grouped.map(\.id), DocumentCorpus.documents.map(\.id),
                       "Grouping must preserve corpus order and lose nothing")
        XCTAssertEqual(DocumentCorpus.countries.count, Set(DocumentCorpus.documents.map(\.countryCode)).count)
        XCTAssertEqual(DocumentCorpus.featured?.id, "us-passport")
    }

    /// The sheets were designed around a 2 × 2 inch cell. Deriving the grid from
    /// the physical size must reproduce those counts exactly, or a US customer
    /// silently loses photos from a sheet they already understand.
    func testPrintGridsReproduceTheDesignedUSCounts() throws {
        let passport = try XCTUnwrap(DocumentCorpus.document(id: "us-passport"))
        let expected: [(PrintSheetLayout, Int)] = [
            (.fourBySix, 4), (.fiveBySeven, 6), (.letter12, 12), (.letter20, 20)
        ]
        for (layout, count) in expected {
            let plan = PrintPlan(layout: layout, spec: passport)
            XCTAssertEqual(plan.count, count, "\(layout.title) must hold \(count) US passport photos")
        }
    }

    func testPrintGridsStayTrueSizeForOtherFormats() throws {
        for id in ["ca-passport", "de-schengen-visa"] {
            let spec = try XCTUnwrap(DocumentCorpus.document(id: id))
            let widthPoints = CGFloat(spec.widthMM) * 72.0 / 25.4
            let heightPoints = CGFloat(spec.heightMM) * 72.0 / 25.4
            for layout in PrintSheetLayout.allCases {
                let plan = PrintPlan(layout: layout, spec: spec)
                XCTAssertEqual(plan.photoSize.width, widthPoints, accuracy: 0.001, "\(id)/\(layout)")
                XCTAssertEqual(plan.photoSize.height, heightPoints, accuracy: 0.001, "\(id)/\(layout)")
                XCTAssertGreaterThanOrEqual(plan.columns, 1, "\(id)/\(layout)")
                XCTAssertGreaterThanOrEqual(plan.rows, 1, "\(id)/\(layout)")

                let page = layout.pageSizePoints
                let gridWidth = CGFloat(plan.columns) * plan.photoSize.width
                let gridHeight = CGFloat(plan.rows) * plan.photoSize.height
                XCTAssertLessThanOrEqual(gridWidth, page.width + 0.5,
                                         "\(id)/\(layout): the grid must not exceed the page")
                XCTAssertLessThanOrEqual(gridHeight, page.height + 0.5,
                                         "\(id)/\(layout): the grid must not exceed the page")
            }
        }
    }

    func testNewDocumentsProduceOnlyApplicableRules() throws {
        for id in ["ca-passport", "de-schengen-visa"] {
            let spec = try XCTUnwrap(DocumentCorpus.document(id: id))
            let findings = ValidationEngine.findings(
                geometry: nil,
                background: nil,
                spec: spec,
                imagePixelSize: CGSize(width: 1000, height: 1000),
                captureDate: nil
            )
            XCTAssertFalse(findings.contains { $0.id == .headHeightShare },
                           "\(id): no published share means no share rule")
            XCTAssertFalse(findings.contains { $0.id == .eyeLine },
                           "\(id): no published eye line means no eye-line rule")
            XCTAssertEqual(findings.first { $0.id == .headHeight }?.status, .cannotVerify)
            XCTAssertEqual(ValidationEngine.overall(for: findings), .cannotVerify)
        }
    }

    /// Background guidance must name this document's own requirement. A single
    /// hardcoded "US workflows require white" sentence was wrong for every
    /// other country as soon as a second one existed.
    func testBackgroundFailureNamesTheDocumentsOwnRequirement() throws {
        let spec = try XCTUnwrap(DocumentCorpus.document(id: "de-schengen-visa"))
        let coloured = BackgroundColorReport(meanLuminance: 0.12, meanChroma: 0.9,
                                             whiteFraction: 0, sampleCount: 900)
        let report = BackgroundReport(uniformitySigma: 0.001, crownContrast: 0.4,
                                      edgeResidualFraction: 0, failingRegions: [], color: coloured)
        let findings = ValidationEngine.findings(
            geometry: nil, background: report, spec: spec,
            imagePixelSize: CGSize(width: 1000, height: 1000), captureDate: nil
        )
        let finding = try XCTUnwrap(findings.first { $0.id == .backgroundUniformity })
        XCTAssertEqual(finding.status, .fail)
        XCTAssertTrue(finding.detail.contains("white or off-white"),
                      "The finding must quote the German requirement: \(finding.detail)")
    }
}
