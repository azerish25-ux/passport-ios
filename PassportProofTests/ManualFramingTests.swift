import XCTest
@testable import PassportProof

final class ManualFramingTests: XCTestCase {
    func testSuggestedGuidesAreOnlyIllustrationsAndLeaveReviewPending() {
        for spec in DocumentCorpus.documents {
            let guides = ManualFramingGuides.suggested(for: spec)
            let assessment = ManualFramingAssessment(guides: guides, spec: spec)
            XCTAssertTrue(assessment.isValid, "\(spec.id): \(assessment.issues)")
            let record = ManualFramingRecord(guides: guides, review: .pending,
                                             documentID: spec.id, revision: UUID())
            XCTAssertFalse(record.review.allConfirmed,
                           "An in-range starting drawing is not a measurement of a photograph or a user confirmation.")
        }
    }

    func testGuideMeasurementsUseTheAcceptedPhotoAndTopOrigin() throws {
        let spec = try document("us-visa")
        let guides = ManualFramingGuides(topY: 0.10, chinY: 0.70, eyeY: 0.38, centerX: 0.55)
        let assessment = ManualFramingAssessment(guides: guides, spec: spec)
        XCTAssertTrue(assessment.isValid, assessment.issues.joined(separator: "; "))
        XCTAssertEqual(assessment.headHeightShare, 0.60, accuracy: 0.000_000_001)
        XCTAssertEqual(assessment.headHeightMM, 30.48, accuracy: 0.000_000_001)
        XCTAssertEqual(assessment.eyeLineFromBottomMM, 31.496, accuracy: 0.000_000_001)
        XCTAssertEqual(assessment.horizontalOffsetMM, 2.54, accuracy: 0.000_000_001)
    }

    func testEveryGuideRejectsNonfiniteAndOutsidePhotoValues() throws {
        let spec = try document("us-visa")
        let fields: [WritableKeyPath<ManualFramingGuides, Double>] = [\.topY, \.chinY, \.eyeY, \.centerX]
        for field in fields {
            for invalid in [Double.nan, .infinity, -.infinity, -0.001, 1.001] {
                var guides = validGuides
                guides[keyPath: field] = invalid
                let assessment = ManualFramingAssessment(guides: guides, spec: spec)
                XCTAssertFalse(assessment.isValid, "Invalid coordinate: \(invalid)")
                XCTAssertFalse(assessment.issues.isEmpty)
            }
        }
    }

    func testTopEyesAndChinMustBeStrictlyOrdered() throws {
        let spec = try document("us-visa")
        let cases = [
            ManualFramingGuides(topY: 0.38, chinY: 0.70, eyeY: 0.38, centerX: 0.5),
            ManualFramingGuides(topY: 0.40, chinY: 0.70, eyeY: 0.38, centerX: 0.5),
            ManualFramingGuides(topY: 0.10, chinY: 0.38, eyeY: 0.38, centerX: 0.5),
            ManualFramingGuides(topY: 0.10, chinY: 0.35, eyeY: 0.38, centerX: 0.5),
            ManualFramingGuides(topY: 0.70, chinY: 0.10, eyeY: 0.38, centerX: 0.5)
        ]
        for guides in cases {
            let assessment = ManualFramingAssessment(guides: guides, spec: spec)
            XCTAssertFalse(assessment.isValid)
            XCTAssertTrue(assessment.issues.contains { $0.contains("above the eyes") })
        }
    }

    func testPassportHeadHeightIncludesEndpointsAndRejectsOutsideWithoutClamping() throws {
        let spec = try document("us-passport")
        for height in [25.0, 35.0] {
            let guides = ManualFramingGuides(topY: 0, chinY: height / spec.heightMM, eyeY: 0.38, centerX: 0.5)
            XCTAssertTrue(ManualFramingAssessment(guides: guides, spec: spec).isValid)
        }
        for height in [24.999_999, 35.000_001] {
            let guides = ManualFramingGuides(topY: 0, chinY: height / spec.heightMM, eyeY: 0.38, centerX: 0.5)
            let assessment = ManualFramingAssessment(guides: guides, spec: spec)
            XCTAssertFalse(assessment.isValid)
            XCTAssertEqual(assessment.headHeightMM, height, accuracy: 0.000_000_001,
                           "Out-of-range measurements must remain unchanged.")
            XCTAssertTrue(assessment.issues.contains { $0.contains("skull crown, excluding hair") })
        }
    }

    func testDigitalHeadShareIncludesEndpointsAndRejectsOutsideWithoutClamping() throws {
        for id in ["us-visa", "us-dv-lottery"] {
            let spec = try document(id)
            for share in [0.50, 0.69] {
                let guides = ManualFramingGuides(topY: 0.10, chinY: 0.10 + share, eyeY: 0.38, centerX: 0.5)
                XCTAssertTrue(ManualFramingAssessment(guides: guides, spec: spec).isValid, id)
            }
            for share in [0.499_999, 0.690_001] {
                let guides = ManualFramingGuides(topY: 0.10, chinY: 0.10 + share, eyeY: 0.38, centerX: 0.5)
                let assessment = ManualFramingAssessment(guides: guides, spec: spec)
                XCTAssertFalse(assessment.isValid, id)
                XCTAssertEqual(assessment.headHeightShare, share, accuracy: 0.000_000_001)
                XCTAssertTrue(assessment.issues.contains { $0.contains("including hair") })
            }
        }
    }

    func testEyeBandIncludesPublishedEndpointsAndRejectsOutside() throws {
        for id in ["us-visa", "us-dv-lottery"] {
            let spec = try document(id)
            // Decimal upper endpoint 0.31 deliberately exercises normalised
            // subtraction roundoff, not a relaxed photographic tolerance.
            for eyeY in [0.31, 0.44] {
                var guides = validGuides
                guides.eyeY = eyeY
                XCTAssertTrue(ManualFramingAssessment(guides: guides, spec: spec).isValid, id)
            }
            for eyeY in [0.309_999, 0.440_001] {
                var guides = validGuides
                guides.eyeY = eyeY
                let assessment = ManualFramingAssessment(guides: guides, spec: spec)
                XCTAssertFalse(assessment.isValid, id)
                XCTAssertTrue(assessment.issues.contains { $0.contains("above the bottom edge") })
            }
        }
        // Passport has no published eye-height band in this corpus. It still
        // requires the eye guide to lie strictly between the head guides.
        let passport = try document("us-passport")
        var guides = validGuides
        guides.eyeY = 0.50
        XCTAssertTrue(ManualFramingAssessment(guides: guides, spec: passport).isValid)
    }

    func testCentringIncludesBothAppBoundariesAndRejectsOutside() throws {
        let spec = try document("us-visa")
        for sign in [-1.0, 1.0] {
            var guides = validGuides
            guides.centerX = 0.5 + sign * ValidationEngine.centringToleranceMM / spec.widthMM
            let boundary = ManualFramingAssessment(guides: guides, spec: spec)
            XCTAssertTrue(boundary.isValid)
            XCTAssertEqual(boundary.horizontalOffsetMM, 3, accuracy: 0.000_000_001)

            guides.centerX += sign * 0.000_001
            let outside = ManualFramingAssessment(guides: guides, spec: spec)
            XCTAssertFalse(outside.isValid)
            XCTAssertGreaterThan(outside.horizontalOffsetMM, ValidationEngine.centringToleranceMM)
            XCTAssertTrue(outside.issues.contains { $0.contains("not a published issuer measurement") })
        }
    }

    func testWorkflowUsesPublishedShareOrPrintedMillimetresAndNamesHeadReference() throws {
        let passport = try document("us-passport")
        let visa = try document("us-visa")
        XCTAssertEqual(passport.headMeasurement, .skull)
        XCTAssertEqual(visa.headMeasurement, .includingHair)

        let printedLowerBoundary = ManualFramingGuides(topY: 0, chinY: 25 / 50.8, eyeY: 0.38, centerX: 0.5)
        XCTAssertTrue(ManualFramingAssessment(guides: printedLowerBoundary, spec: passport).isValid)
        XCTAssertFalse(ManualFramingAssessment(guides: printedLowerBoundary, spec: visa).isValid,
                       "25 mm is below the digital workflow's published 50% minimum.")
        let digitalUpperBoundary = ManualFramingGuides(topY: 0.10, chinY: 0.79, eyeY: 0.38, centerX: 0.5)
        XCTAssertTrue(ManualFramingAssessment(guides: digitalUpperBoundary, spec: visa).isValid)
        XCTAssertFalse(ManualFramingAssessment(guides: digitalUpperBoundary, spec: passport).isValid,
                       "69% exceeds the printed passport's 35 mm maximum.")
    }

    func testEveryManualConfirmationIsRequired() {
        XCTAssertFalse(ManualFramingReview.pending.allConfirmed)
        let complete = ManualFramingReview(guidesConfirmed: true, singleFaceAndPoseConfirmed: true,
                                           backgroundAndLightingConfirmed: true, limitationsAccepted: true)
        XCTAssertTrue(complete.allConfirmed)
        let fields: [WritableKeyPath<ManualFramingReview, Bool>] = [
            \.guidesConfirmed, \.singleFaceAndPoseConfirmed, \.backgroundAndLightingConfirmed, \.limitationsAccepted
        ]
        for field in fields {
            var incomplete = complete
            incomplete[keyPath: field] = false
            XCTAssertFalse(incomplete.allConfirmed)
        }
    }

    func testRecordKeepsItsOwnDraftSnapshotAndBindsDocumentAndRevision() {
        var guides = validGuides
        var review = ManualFramingReview.pending
        let revision = UUID()
        let record = ManualFramingRecord(guides: guides, review: review, documentID: "us-visa", revision: revision)
        guides.eyeY = 0.42
        review.guidesConfirmed = true
        XCTAssertEqual(record.guides, validGuides)
        XCTAssertEqual(record.review, .pending)
        XCTAssertEqual(record.documentID, "us-visa")
        XCTAssertEqual(record.revision, revision)
        XCTAssertNotEqual(record, ManualFramingRecord(guides: record.guides, review: record.review,
                                                       documentID: "us-passport", revision: revision))
        XCTAssertNotEqual(record, ManualFramingRecord(guides: record.guides, review: record.review,
                                                       documentID: "us-visa", revision: UUID()))
    }

    private var validGuides: ManualFramingGuides {
        ManualFramingGuides(topY: 0.10, chinY: 0.70, eyeY: 0.38, centerX: 0.5)
    }

    private func document(_ id: String) throws -> DocumentSpec {
        try XCTUnwrap(DocumentCorpus.document(id: id))
    }
}
