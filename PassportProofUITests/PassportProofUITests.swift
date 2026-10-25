//
//  PassportProofUITests.swift
//  PassportProofUITests
//
//  Real navigation, PhotosPicker, image analysis, StoreKit and system sharing.
//  CI imports one full-resolution portrait into the disposable simulator's
//  Photos library. Its historical sample photos may also be present. No photo
//  fixture or entitlement bypass is added to the app.
//  Run serially: StoreKitTest controls one shared environment per simulator.
//

import XCTest
import StoreKitTest

final class PassportProofUITests: XCTestCase {
    private let productIdentifier = "com.passportproof.app.unlock"
    private let manualReviewIDs = ["manual.review.guides", "manual.review.face", "manual.review.background", "manual.review.limitations"]
    private var storeSession: SKTestSession!
    private var testedApp: XCUIApplication?

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        let configuration = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "PassportProof", withExtension: "storekit"),
            "The canonical StoreKit configuration must be copied into the UI-test bundle"
        )
        storeSession = try SKTestSession(contentsOf: configuration)
        storeSession.resetToDefaultState()
        storeSession.clearTransactions()
        storeSession.disableDialogs = true
    }

    override func tearDown() async throws {
        await MainActor.run {
            if let app = testedApp, app.state == .runningForeground {
                // Dismiss an observed system picker before ending its host.
                // A failed import can otherwise leave the remote Photos UI
                // open while the next test begins another picker session.
                let pickerNavigation = app.navigationBars.matching(NSPredicate(
                    format: "identifier IN %@", ["Photos", "PUPickerUnavailableView"]
                )).firstMatch
                if pickerNavigation.exists {
                    let cancel = pickerNavigation.buttons["Cancel"]
                    if cancel.exists && cancel.isHittable {
                        print("PHOTOS PICKER teardown: dismissing \(pickerNavigation.identifier)")
                        cancel.tap()
                    }
                }
            }
            testedApp?.terminate()
            testedApp = nil
        }
        storeSession?.clearTransactions()
        storeSession = nil
        try await super.tearDown()
    }

    @MainActor
    func testLibraryCatalogueAndPrimaryAction() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["library.start"].exists)
        XCTAssertTrue(app.buttons["library.document.us-passport"].exists)
        XCTAssertTrue(app.buttons["library.document.us-visa"].exists)
        XCTAssertTrue(app.buttons["library.document.us-dv-lottery"].exists)
        XCTAssertTrue(app.buttons["library.privacy"].exists)
        capture(app, named: "01-library")
    }

    @MainActor
    func testLibraryRemainsActionableAtAccessibilityTextSize() {
        let app = launchApp(arguments: ["-UITestLargeText"])
        scrollToHittable(app.buttons["library.start"], in: app)
        capture(app, named: "05-library-accessibility-text")
        scrollToHittable(app.buttons["library.privacy"], in: app)
        app.buttons["library.privacy"].tap()
        require(app.staticTexts["Private by design"], in: app)
        capture(app, named: "05-privacy-accessibility-text")
    }

    @MainActor
    func testPrivacyDisclosureOpensFromLibrary() {
        let app = launchApp()
        scrollToHittable(app.buttons["library.privacy"], in: app)
        app.buttons["library.privacy"].tap()
        require(app.staticTexts["Private by design"], in: app)
        XCTAssertTrue(app.staticTexts["Photos"].exists)
        XCTAssertTrue(app.staticTexts["Data collection"].exists)
        capture(app, named: "02-privacy")
    }

    @MainActor
    func testDocumentDetailLeadsToCaptureSources() {
        let app = launchApp()
        openCapture(in: app)
        XCTAssertTrue(app.buttons["capture.camera"].exists)
        XCTAssertTrue(app.buttons["capture.library"].exists)
        XCTAssertFalse(app.buttons["capture.camera"].isEnabled, "The simulator must offer import when camera hardware is absent")
        XCTAssertTrue(app.buttons["capture.library"].isEnabled)
        capture(app, named: "03-capture-sources")
    }

    @MainActor
    func testLibraryUnlockRouteShowsPurchaseArea() {
        let app = launchApp()
        openUnlock(in: app)
        require(app.buttons["unlock.purchase"], in: app, timeout: 20)
        XCTAssertTrue(app.navigationBars["Export unlock"].exists)
        XCTAssertTrue(app.buttons["unlock.restore"].exists)
        capture(app, named: "04-unlock")
    }

    @MainActor
    func testLibraryAndCaptureInDarkMode() {
        let app = launchApp(arguments: ["-UITestDarkMode"])
        capture(app, named: "06-library-dark")
        openCapture(in: app)
        scrollToHittable(app.buttons["capture.library"], in: app)
        capture(app, named: "06-capture-dark")
    }

    @MainActor
    func testPurchaseButtonAndFreshLaunchRestoreVerifiedEntitlement() {
        let app = launchApp()
        openUnlock(in: app)
        let purchase = app.buttons["unlock.purchase"]
        require(purchase, in: app, timeout: 20)
        scrollToHittable(purchase, in: app)
        XCTAssertTrue(storeSession.allTransactions().isEmpty)
        capture(app, named: "07-storekit-before-purchase")
        purchase.tap()

        waitUntil(in: app, description: "The app purchase must create a StoreKit transaction", timeout: 25) {
            !self.storeSession.allTransactions().isEmpty
        }
        // UnlockView only dismisses after the production store has verified the
        // purchase. The debug demonstration action is never used by this suite.
        require(app.buttons["library.start"], in: app, timeout: 20)
        XCTAssertEqual(storeSession.allTransactions().count, 1)
        capture(app, named: "07-storekit-purchased")

        app.terminate()
        app.launch()
        require(app.buttons["library.start"], in: app, timeout: 20)
        openUnlock(in: app)
        let verified = app.staticTexts["Export is unlocked for this Apple Account."]
        require(verified, in: app, timeout: 20)
        XCTAssertFalse(app.buttons["unlock.purchase"].exists, "A fresh process must recover the verified non-consumable entitlement")
        let restore = app.buttons["unlock.restore"]
        scrollToHittable(restore, in: app)
        restore.tap()
        waitUntil(in: app, description: "Restore must finish with the verified entitlement intact", timeout: 20) {
            verified.exists && restore.isEnabled
        }
        XCTAssertEqual(storeSession.allTransactions().count, 1, "Restore must not create another purchase")
        capture(app, named: "07-storekit-restored-after-relaunch")
    }

    @MainActor
    func testManualFramingFromRealPhotoPreservesEditsAndSharesJPEG() throws {
        executionTimeAllowance = 480
        // This transaction uses Apple's local StoreKit environment. The separate
        // purchase test above exercises the application's purchase button.
        try storeSession.buyProduct(productIdentifier: productIdentifier)
        let app = launchApp()
        openCapture(in: app)
        importSeededPortrait(in: app)

        let confirmCrop = app.buttons["crop.confirm"]
        require(confirmCrop, in: app, timeout: 30)
        waitUntil(in: app, description: "The original photo must finish preparing", timeout: 30) { confirmCrop.isEnabled }
        includeWholeHeadInManualCrop(in: app)
        capture(app, named: "08-real-photo-crop")
        confirmCrop.tap()

        let photo = app.images["analysis.photo"]
        require(photo, in: app, timeout: 40)
        capture(app, named: "08-real-photo-analysis")
        attachHierarchy(app, named: "08-real-analysis-findings")

        manuallyFramePortrait(in: app, printedPassport: false, evidencePrefix: "08")
        let reviewIDs = confirmVisualReview(in: app)
        try verifyManualDraftCancellation(in: app, reviewIDs: reviewIDs)

        // A draft rotation/reset must not destroy the accepted photo or its
        // completed review when the user cancels. Session unit tests additionally
        // verify original pixel retention and accepted-crop revision isolation.
        let edit = app.buttons["analysis.editCrop"]
        scrollToHittable(edit, in: app, towardTop: true, within: analysisViewport(in: app))
        edit.tap()
        require(app.buttons["crop.cancel"], in: app)
        waitUntil(in: app, description: "The retained original must reopen for editing", timeout: 30) {
            app.buttons["crop.confirm"].isEnabled
        }
        let rotate = app.buttons["crop.rotate"]
        scrollToHittable(rotate, in: app, within: cropViewport(in: app))
        rotate.tap()
        waitUntil(in: app, description: "Rotation must finish", timeout: 30) { app.buttons["crop.reset"].isEnabled }
        scrollToHittable(app.buttons["crop.reset"], in: app, within: cropViewport(in: app))
        app.buttons["crop.reset"].tap()
        waitUntil(in: app, description: "Reset must finish", timeout: 30) { app.buttons["crop.confirm"].isEnabled }

        // Check lifecycle preservation through public UI operations. A distinct
        // draft zoom makes a silently recreated editor observable. This does not
        // inspect or make claims about the system's private app-switcher image.
        let zoom = app.sliders["crop.zoom"]
        scrollToHittable(zoom, in: app, towardTop: true, within: cropViewport(in: app))
        let resetZoom = try XCTUnwrap(zoom.value as? String)
        zoom.adjust(toNormalizedSliderPosition: 0.2)
        waitUntil(in: app, description: "The draft zoom must change before testing restoration", timeout: 5) {
            (zoom.value as? String) != resetZoom
        }
        let draftZoom = try XCTUnwrap(zoom.value as? String)
        let dimensions = app.descendants(matching: .any)["crop.dimensions"]
        require(dimensions, in: app)
        let draftDimensions = dimensions.label
        XCUIDevice.shared.press(.home)
        waitUntil(in: app, description: "The application must remain running in the background", timeout: 10) {
            app.state == .runningBackground || app.state == .runningBackgroundSuspended
        }
        app.activate()
        require(app.buttons["crop.cancel"], in: app)
        waitUntil(in: app, description: "The privacy cover must release the active crop editor", timeout: 5) {
            !app.descendants(matching: .any)["privacy.shield"].exists && app.buttons["crop.cancel"].isHittable
        }
        XCTAssertEqual(zoom.value as? String, draftZoom, "Returning to the app must preserve the draft crop")
        XCTAssertEqual(dimensions.label, draftDimensions)
        XCTAssertTrue(app.buttons["crop.confirm"].isEnabled)
        capture(app, named: "08-real-photo-draft-edit")
        app.buttons["crop.cancel"].tap()
        require(photo, in: app)
        assertManualStatus(in: app, identifier: "analysis.manualStatus")
        for identifier in reviewIDs {
            XCTAssertEqual(app.switches[identifier].value as? String, "1", "Canceling a crop must preserve the accepted photo's review")
        }

        let next = app.buttons["analysis.continue"]
        // This exercises the disclosed manual product path. The separate
        // automatic-landmark regressions remain strict and are not bypassed.
        require(next, in: app, timeout: 10)
        waitUntil(in: app, description: "Explicit manual framing and visual review must enable the digital export", timeout: 10) { next.isEnabled }
        next.tap()
        let uncertain = app.alerts["Review the unverified checks"]
        require(uncertain, in: app)
        capture(app, named: "08-manual-measurements-disclosure")
        uncertain.buttons["Continue to export"].tap()

        let export = app.buttons["export.primary"]
        require(export, in: app, timeout: 15)
        XCTAssertEqual(export.label, "Export JPEG", "The verified purchase and real review must unlock the digital export")
        assertManualStatus(in: app, identifier: "export.manualStatus")
        XCTAssertTrue(app.descendants(matching: .any)["export.preview"].exists)
        let digitalPreview = app.images["Your complete reviewed crop, without any additional cropping"]
        scrollToHittable(digitalPreview, in: app, within: exportViewport(in: app, title: "Visa"))
        capture(app, named: "08-digital-export-preview")
        export.tap()

        waitUntil(in: app, description: "A generated file must reach the system activity sheet", timeout: 25) {
            app.buttons["Save to Files"].exists || app.buttons["Save Image"].exists ||
                app.buttons["Copy"].exists || app.otherElements["ActivityListView"].exists
        }
        capture(app, named: "08-system-share-sheet")
        attachHierarchy(app, named: "08-system-share-file-details")
    }

    @MainActor
    func testManualPassportFramingPrintLayoutsAndPDFShare() throws {
        executionTimeAllowance = 480
        try storeSession.buyProduct(productIdentifier: productIdentifier)
        let app = launchApp()
        openCapture(in: app, documentID: "us-passport")
        importSeededPortrait(in: app, evidencePrefix: "09")

        let confirmCrop = app.buttons["crop.confirm"]
        require(confirmCrop, in: app, timeout: 30)
        waitUntil(in: app, description: "The passport crop must finish preparing", timeout: 30) { confirmCrop.isEnabled }
        includeWholeHeadInManualCrop(in: app)
        capture(app, named: "09-passport-crop")
        confirmCrop.tap()
        require(app.images["analysis.photo"], in: app, timeout: 40)
        capture(app, named: "09-passport-analysis")
        attachHierarchy(app, named: "09-real-passport-findings")
        manuallyFramePortrait(in: app, printedPassport: true, evidencePrefix: "09", checkInvalidGuides: true)
        confirmVisualReview(in: app)

        let next = app.buttons["analysis.continue"]
        require(next, in: app, timeout: 10)
        waitUntil(in: app, description: "The manually framed passport and explicit confirmations must permit export", timeout: 10) { next.isEnabled }
        next.tap()
        let uncertain = app.alerts["Review the unverified checks"]
        require(uncertain, in: app)
        capture(app, named: "09-passport-manual-disclosure")
        uncertain.buttons["Continue to export"].tap()

        let export = app.buttons["export.primary"]
        require(export, in: app, timeout: 15)
        XCTAssertEqual(export.label, "Export PDF", "The reviewed passport crop and verified purchase must enable PDF export")
        assertManualStatus(in: app, identifier: "export.manualStatus")
        XCTAssertTrue(app.buttons["export.calibration"].exists)

        // Exercise the four actual supported layouts, including the dense
        // Letter sheet. The image label only exists after PDF rasterization.
        let layouts: [(identifier: String, title: String, copies: Int)] = [
            ("fourBySix", "4 × 6 in", 4),
            ("fiveBySeven", "5 × 7 in", 6),
            ("letter12", "Letter — 12-up", 12),
            ("letter20", "Letter — 20-up", 20),
        ]
        for (index, layout) in layouts.enumerated() {
            // Reveal the regular heading before querying its lazy grid cells.
            scrollToHittable(app.staticTexts["Choose your paper"], in: app, within: exportViewport(in: app, title: "Passport"))
            let choice = app.buttons["layout.\(layout.identifier)"]
            scrollToHittable(choice, in: app, within: exportViewport(in: app, title: "Passport"))
            if index == 0 {
                XCTAssertTrue(choice.isSelected, "The initial sheet must be the default 4 × 6 inch layout")
            } else {
                choice.tap()
                waitUntil(in: app, description: "The selected paper must update to \(layout.title)", timeout: 10) { choice.isSelected }
            }
            for other in layouts where other.identifier != layout.identifier {
                XCTAssertFalse(app.buttons["layout.\(other.identifier)"].isSelected, "Only the current paper choice may be selected")
            }

            let previewLabel = "Preview of the actual \(layout.title) PDF with \(layout.copies) copies of your reviewed photo"
            let preview = app.images[previewLabel]
            require(preview, in: app, timeout: 25)
            scrollToHittable(preview, in: app, towardTop: true, within: exportViewport(in: app, title: "Passport"))
            XCTAssertTrue(app.staticTexts["\(layout.title) · \(layout.copies) photos · print at 100%"].exists)
            capture(app, named: "09-print-preview-\(layout.identifier)")
        }

        XCTAssertEqual(export.label, "Export PDF")
        XCTAssertTrue(export.isEnabled)
        export.tap()
        waitUntil(in: app, description: "The generated passport PDF must reach the system activity sheet", timeout: 25) {
            app.buttons["Save to Files"].exists || app.buttons["Copy"].exists ||
                app.otherElements["ActivityListView"].exists
        }
        capture(app, named: "09-passport-pdf-share-sheet")
        attachHierarchy(app, named: "09-passport-pdf-file-details")
    }

    // MARK: - Navigation and evidence

    @MainActor
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + arguments
        testedApp = app
        app.launch()
        require(app.buttons["library.start"], in: app, timeout: 20)
        return app
    }

    @MainActor
    private func openCapture(in app: XCUIApplication, documentID: String = "us-visa") {
        let document = app.buttons["library.document.\(documentID)"]
        scrollToHittable(document, in: app)
        document.tap()
        let measure = app.buttons["detail.measure"]
        scrollToHittable(measure, in: app)
        measure.tap()
        require(app.buttons["capture.library"], in: app)
    }

    @MainActor
    private func openUnlock(in app: XCUIApplication) {
        let unlock = app.buttons["library.unlock"]
        scrollToHittable(unlock, in: app)
        unlock.tap()
        require(app.descendants(matching: .any)["unlock.purchaseArea"], in: app, timeout: 15)
    }

    @MainActor
    private func importSeededPortrait(in app: XCUIApplication, evidencePrefix: String = "08") {
        let library = app.buttons["capture.library"]
        scrollToHittable(library, in: app)
        library.tap()
        // These identifiers come from the actual system-picker hierarchy. Its
        // loading screen leaves the app's hidden photo.on.rectangle icon in the
        // accessibility tree, so an app-wide 'Photo' image query is unsafe.
        let photosNavigation = app.navigationBars["Photos"]
        // The recorded simulator kept the real PUPickerUnavailableView loading
        // past 20 seconds. Wait for the actual Photos UI, never an app icon.
        require(photosNavigation, in: app, timeout: 45)
        let pickers = app.scrollViews.matching(identifier: "photosView_content_scroll_view")
        let picker = pickers.firstMatch
        require(picker, in: app, timeout: 20)
        let grids = picker.otherElements.matching(identifier: "PXGGridLayout-Group")
        let grid = grids.firstMatch
        require(grid, in: app, timeout: 20)
        let assets = grid.images.matching(NSPredicate(
            format: "identifier == %@ AND label BEGINSWITH %@", "PXGGridLayout-Info", "Photo, "
        ))
        let portrait = assets.firstMatch
        require(portrait, in: app, timeout: 20)
        print("PHOTOS PICKER resolved navigation=\(photosNavigation.exists), pickers=\(pickers.count), grids=\(grids.count), assets=\(assets.count)")
        // PhotoKit's virtual grid image exists and has a correct visible frame
        // on iOS 26.2, but reports isHittable=false. Validate this exact asset's
        // bounds before tapping its center; never substitute a background icon.
        waitUntil(in: app, description: "The newest PhotosPicker asset must be fully visible below its navigation bar", timeout: 10) {
            let frame = portrait.frame
            let visiblePicker = picker.frame.intersection(app.frame)
            return frame.width >= 30 && frame.height >= 30 &&
                visiblePicker.contains(frame) && frame.minY >= photosNavigation.frame.maxY
        }
        // CI adds this portrait immediately after erasing the simulator. The
        // picker sorts newest first; the runtime's sample assets are historical.
        let selectedLabel = portrait.label
        print("PHOTOS PICKER selecting newest asset: \(selectedLabel); frame=\(portrait.frame); isHittable=\(portrait.isHittable); pickerFrame=\(picker.frame)")
        attachHierarchy(app, named: "\(evidencePrefix)-system-photos-picker")
        capture(app, named: "\(evidencePrefix)-photos-picker")
        func tapSameVisibleAsset() {
            var previousFrame = CGRect.null
            var stableObservations = 0
            let screenFrame = app.frame
            // Each remote AX observation took several seconds in the recorded
            // run. Two complete observations must fit within this budget.
            waitUntil(in: app, description: "The exact PhotosPicker asset must have a stable visible frame before tapping", timeout: 30) {
                guard photosNavigation.exists, picker.exists,
                      let asset = try? portrait.snapshot(), asset.label == selectedLabel else {
                    previousFrame = .null
                    stableObservations = 0
                    return false
                }
                // A snapshot reads this exact asset's label and frame together.
                let frame = asset.frame
                guard frame.width >= 30, frame.height >= 30,
                      picker.frame.intersection(screenFrame).contains(frame),
                      frame.minY >= photosNavigation.frame.maxY else {
                    previousFrame = .null
                    stableObservations = 0
                    return false
                }
                let unchanged = !previousFrame.isNull &&
                    abs(frame.minX - previousFrame.minX) <= 1 &&
                    abs(frame.minY - previousFrame.minY) <= 1 &&
                    abs(frame.width - previousFrame.width) <= 1 &&
                    abs(frame.height - previousFrame.height) <= 1
                stableObservations = unchanged ? stableObservations + 1 : 1
                previousFrame = frame
                print("PHOTOS PICKER stable observation \(stableObservations): \(asset.label); frame=\(frame)")
                return stableObservations >= 2
            }
            let frame = portrait.frame
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: frame.midX - app.frame.minX, dy: frame.midY - app.frame.minY
            )).tap()
        }
        tapSameVisibleAsset()
        let crop = app.buttons["crop.confirm"]
        if !crop.waitForExistence(timeout: 8), photosNavigation.exists, picker.exists,
           portrait.exists, portrait.label == selectedLabel {
            // The recorded failure left this exact grid untouched after the
            // first tap. Retry once only while the same picker remains open;
            // never send a second tap into a dismissed picker or crop editor.
            capture(app, named: "\(evidencePrefix)-picker-selection-not-accepted")
            attachHierarchy(app, named: "\(evidencePrefix)-picker-selection-not-accepted")
            tapSameVisibleAsset()
        }
        require(app.buttons["crop.confirm"], in: app, timeout: 30)
    }

    // MARK: - Explicit manual framing with the real imported photograph

    @MainActor
    private func includeWholeHeadInManualCrop(in app: XCUIApplication) {
        // The unmodified fixture is 1062x1210. A centered square removes 74px
        // at the top and clips the hairstyle. Reset zoom, then move the actual
        // image down until the square reaches the source's top boundary.
        let reset = app.buttons["crop.reset"]
        scrollToHittable(reset, in: app, within: cropViewport(in: app))
        reset.tap()
        waitUntil(in: app, description: "The full-resolution original must finish resetting", timeout: 30) {
            app.buttons["crop.confirm"].isEnabled
        }
        let preview = app.descendants(matching: .any)["crop.preview"]
        scrollToHittable(preview, in: app, towardTop: true, within: cropViewport(in: app))
        let start = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        let end = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        start.press(forDuration: 0.05, thenDragTo: end)
        print("MANUAL QA: source top aligned through the real crop gesture; \(app.descendants(matching: .any)["crop.dimensions"].label)")
    }

    @MainActor
    private func manuallyFramePortrait(in app: XCUIApplication, printedPassport: Bool,
                                      evidencePrefix: String, checkInvalidGuides: Bool = false) {
        require(app.staticTexts["analysis.automaticUnavailable"], in: app)
        XCTAssertFalse(app.staticTexts["analysis.manualStatus"].exists)
        openManualFraming(in: app)
        require(app.staticTexts["manual.automaticUnavailable"], in: app)
        let save = app.buttons["manual.confirm"]
        XCTAssertFalse(save.isEnabled, "Suggested positions must never grant manual approval")

        // These are visual estimates on the inspected, unretouched source, now
        // anchored at y=0 in a 1062px square. The skull is under the hairstyle;
        // the anatomical chin is above the beard tip. This is a manual workflow
        // test, not landmark ground truth or evidence of issuer acceptance.
        let top: CGFloat = printedPassport ? 110.0 / 1062.0 : 40.0 / 1062.0
        let positions: [(String, CGFloat)] = [
            ("manual.top", checkInvalidGuides ? 0.95 : top),
            ("manual.chin", 710.0 / 1062.0),
            ("manual.eyes", 390.0 / 1062.0),
            ("manual.center", 560.0 / 1062.0),
        ]
        for (identifier, position) in positions {
            setManualGuide(identifier, to: position, in: app)
        }
        if checkInvalidGuides {
            // Negative gate: all attestations cannot make a top-below-chin
            // guide set valid. No invalid state is saved or exported.
            require(app.staticTexts["manual.issues"], in: app)
            confirmManualReview(in: app, validGuides: false)
            XCTAssertFalse(save.isEnabled)
            capture(app, named: "\(evidencePrefix)-manual-invalid-guides-blocked")
            attachHierarchy(app, named: "\(evidencePrefix)-manual-invalid-guides-blocked")
            setManualGuide("manual.top", to: top, in: app)
            for identifier in manualReviewIDs {
                XCTAssertEqual(app.switches[identifier].value as? String, "0", "Changing a guide must invalidate its prior attestations")
            }
        }
        XCTAssertFalse(app.staticTexts["manual.issues"].exists, "The manually placed guide estimates must satisfy the published dimensions")
        XCTAssertFalse(save.isEnabled, "Valid guide numbers still require explicit review")
        require(app.images["manual.preview"], in: app)
        capture(app, named: "\(evidencePrefix)-manual-guide-placement")
        confirmManualReview(in: app, validGuides: true)
        capture(app, named: "\(evidencePrefix)-manual-confirmations")
        attachHierarchy(app, named: "\(evidencePrefix)-manual-confirmations")
        save.tap()
        require(app.images["analysis.photo"], in: app)
        assertManualStatus(in: app, identifier: "analysis.manualStatus")
        require(app.buttons["analysis.continue"], in: app)
        XCTAssertFalse(app.buttons["analysis.continue"].isEnabled,
                       "Manual framing does not replace the four ordinary visual checks")
        capture(app, named: "\(evidencePrefix)-analysis-manually-framed")
    }

    @MainActor
    private func setManualGuide(_ identifier: String, to position: CGFloat, in app: XCUIApplication) {
        let slider = app.sliders[identifier]
        scrollToHittable(slider, in: app, within: manualViewport(in: app))
        func readPosition() -> CGFloat? {
            let value = slider.value as? String ?? ""
            guard let number = value.split(separator: " ").first.flatMap({ Double($0) }),
                  number.isFinite, (0...100).contains(number) else { return nil }
            return CGFloat(number / 100)
        }
        guard var actual = readPosition() else {
            failureEvidence(app, named: "manual-guide-value-missing")
            XCTFail("Each guide must expose an accessible numeric position: \(identifier)")
            return
        }
        // XCTest's normalized slider adjustment missed 66.9% as 57.2% on this
        // runtime. Move the observed thumb toward the requested photo feature,
        // then read its real value; at most three physical corrections are made.
        for attempt in 0..<3 where abs(actual - position) > 0.015 {
            let frame = slider.frame
            let inset = min(frame.height / 2, frame.width / 4)
            let trackWidth = frame.width - 2 * inset
            let startX = frame.minX + inset + actual * trackWidth
            let endX = frame.minX + inset + position * trackWidth
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: startX - app.frame.minX, dy: frame.midY - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: endX - app.frame.minX, dy: frame.midY - app.frame.minY))
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: XCUIGestureVelocity(150), thenHoldForDuration: 0.3)
            guard let updated = readPosition() else {
                failureEvidence(app, named: "manual-guide-value-missing")
                XCTFail("The guide position disappeared after adjustment: \(identifier)")
                return
            }
            actual = updated
            print("MANUAL GUIDE \(identifier) attempt=\(attempt + 1): requested=\(position), actual=\(actual), frame=\(frame)")
        }
        if abs(actual - position) > 0.015 { failureEvidence(app, named: "manual-guide-position-failed") }
        XCTAssertEqual(Double(actual), Double(position), accuracy: 0.015,
                       "The UI guide must reach the inspected position, not merely become valid")
    }

    @MainActor
    private func confirmManualReview(in app: XCUIApplication, validGuides: Bool) {
        for (index, identifier) in manualReviewIDs.enumerated() {
            let toggle = app.switches[identifier]
            scrollToHittable(toggle, in: app, within: manualViewport(in: app))
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.tap()
            waitUntil(in: app, description: "Manual confirmation must persist: \(identifier)", timeout: 5) {
                toggle.exists && toggle.value as? String == "1"
            }
            if !validGuides || index < manualReviewIDs.count - 1 {
                XCTAssertFalse(app.buttons["manual.confirm"].isEnabled)
            }
        }
        if validGuides {
            waitUntil(in: app, description: "Valid guides plus all four manual confirmations must enable saving", timeout: 5) {
                app.buttons["manual.confirm"].isEnabled
            }
        }
    }

    @MainActor
    private func verifyManualDraftCancellation(in app: XCUIApplication, reviewIDs: [String]) throws {
        openManualFraming(in: app)
        let center = app.sliders["manual.center"]
        scrollToHittable(center, in: app, within: manualViewport(in: app))
        let acceptedCenter = try XCTUnwrap(center.value as? String)
        XCTAssertTrue(app.buttons["manual.confirm"].isEnabled)
        setManualGuide("manual.center", to: 0.8, in: app)
        XCTAssertNotEqual(center.value as? String, acceptedCenter)
        XCTAssertFalse(app.buttons["manual.confirm"].isEnabled)
        app.buttons["manual.cancel"].tap()
        assertManualStatus(in: app, identifier: "analysis.manualStatus")
        for identifier in reviewIDs {
            XCTAssertEqual(app.switches[identifier].value as? String, "1", "Canceling manual guide edits must preserve ordinary review")
        }
        openManualFraming(in: app)
        scrollToHittable(center, in: app, within: manualViewport(in: app))
        XCTAssertEqual(center.value as? String, acceptedCenter, "Cancel must retain the accepted guide, not its edited draft")
        for identifier in manualReviewIDs {
            XCTAssertEqual(app.switches[identifier].value as? String, "1", "Cancel must preserve the accepted manual attestations")
        }
        XCTAssertTrue(app.buttons["manual.confirm"].isEnabled)
        capture(app, named: "08-manual-draft-cancel-preserved")
        app.buttons["manual.cancel"].tap()
        assertManualStatus(in: app, identifier: "analysis.manualStatus")
    }

    @MainActor
    private func openManualFraming(in app: XCUIApplication) {
        let entry = app.buttons["analysis.manualFraming"]
        scrollToHittable(entry, in: app, towardTop: true, within: analysisViewport(in: app))
        entry.tap()
        require(app.buttons["manual.cancel"], in: app)
        require(app.buttons["manual.confirm"], in: app)
    }

    @MainActor
    private func assertManualStatus(in app: XCUIApplication, identifier: String) {
        let status = app.staticTexts[identifier]
        require(status, in: app)
        XCTAssertEqual(status.label, "Manually framed", "The interface must never label manual input as an automatic pass")
    }

    @MainActor
    private func manualViewport(in app: XCUIApplication) -> CGRect {
        // The photo is pinned outside this ScrollView. Its frame, rather than
        // the full screen, is the actual gesture and visibility region.
        let scroll = app.scrollViews.containing(.slider, identifier: "manual.top").firstMatch
        let save = app.buttons["manual.confirm"]
        let preview = app.images["manual.preview"]
        require(scroll, in: app)
        require(save, in: app)
        require(preview, in: app)
        let hint = app.staticTexts.matching(NSPredicate(format: "label IN %@", [
            "Confirm all four statements to continue.", "Adjust the guide positions to continue."
        ])).firstMatch
        // AX may report a ScrollView frame larger than its visible content.
        // Below the pinned image, the default-text layout has a 10pt gap,
        // 22pt active-guide caption and 12pt padding. Add 10pt clearance.
        let top = max(scroll.frame.minY + 8, preview.frame.maxY + 54)
        let bottom = min(scroll.frame.maxY, hint.exists ? hint.frame.minY : save.frame.minY) - 12
        return CGRect(x: scroll.frame.minX, y: top, width: scroll.frame.width, height: bottom - top)
    }

    @MainActor
    private func cropViewport(in app: XCUIApplication) -> CGRect {
        let cancel = app.buttons["crop.cancel"]
        let save = app.buttons["crop.confirm"]
        require(cancel, in: app)
        require(save, in: app)
        let top = cancel.frame.maxY + 12
        return CGRect(x: app.frame.minX, y: top, width: app.frame.width, height: save.frame.minY - 20 - top)
    }

    @MainActor
    private func analysisViewport(in app: XCUIApplication) -> CGRect {
        let navigation = app.navigationBars["Photo review"]
        let footer = app.buttons.matching(NSPredicate(format: "identifier IN %@", [
            "analysis.adjust", "analysis.manualStart", "analysis.continue"
        ])).firstMatch
        require(navigation, in: app)
        require(footer, in: app)
        let top = navigation.frame.maxY + 8
        return CGRect(x: app.frame.minX, y: top, width: app.frame.width, height: footer.frame.minY - 20 - top)
    }

    @MainActor
    private func exportViewport(in app: XCUIApplication, title: String) -> CGRect {
        let navigation = app.navigationBars[title]
        let footer = app.buttons["export.primary"]
        require(navigation, in: app)
        require(footer, in: app)
        let top = navigation.frame.maxY + 8
        return CGRect(x: app.frame.minX, y: top, width: app.frame.width, height: footer.frame.minY - 20 - top)
    }

    @MainActor
    @discardableResult
    private func confirmVisualReview(in app: XCUIApplication) -> [String] {
        // These interactions exercise required human confirmations; they do not
        // certify that the public QA portrait is an accepted application photo.
        let identifiers = ["review.expression", "review.glasses", "review.recent", "review.original"]
        for identifier in identifiers {
            let toggle = app.switches[identifier]
            // A switch behind the sticky action bar can report isHittable=true.
            // The recorded failure tapped Choose another instead of the fourth
            // switch. Keep the entire row below navigation and above the bar's
            // 12pt top padding, with another 8pt of clearance before tapping.
            let viewport = analysisViewport(in: app)
            scrollToHittable(toggle, in: app, within: viewport)
            print("VISUAL REVIEW \(identifier): frame=\(toggle.frame); safeViewport=\(viewport)")
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.tap()
            waitUntil(in: app, description: "The visual confirmation must persist: \(identifier)", timeout: 5) {
                toggle.exists && toggle.value as? String == "1"
            }
        }
        capture(app, named: "visual-review-confirmed")
        attachHierarchy(app, named: "visual-review-confirmed")
        return identifiers
    }

    @MainActor
    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false, within viewport: CGRect? = nil) {
        require(element, in: app)
        func isReachable() -> Bool {
            element.exists && element.isHittable && (viewport?.contains(element.frame) ?? true)
        }
        let cropZoom = app.sliders["crop.zoom"]
        let isCropEditor = app.buttons["crop.cancel"].exists && cropZoom.exists
        var attempts = 0
        while !isReachable() && attempts < 9 {
            let upward = viewport.map { element.frame.minY < $0.minY } ?? towardTop
            let gestureFrame = viewport ?? app.frame
            let top = gestureFrame.minY + gestureFrame.height * (viewport == nil ? 0.32 : 0.2)
            let bottom = gestureFrame.minY + gestureFrame.height * (viewport == nil ? 0.72 : 0.8)
            // The outer 20pt blank page margin did not receive scrolling in
            // the recorded crop failure. Start inside the visible card's
            // padding, beyond the right edge of its sliders/toggles.
            var x = min(app.frame.maxX, gestureFrame.maxX) - 30
            var startY = upward ? top : bottom
            if isCropEditor {
                // Starting over the photo would move its pixels. The observed
                // zoom row stays visible above the footer; its adjacent card
                // padding is a real scroll surface with no competing gesture.
                let zoomFrame = cropZoom.frame
                x = min(zoomFrame.maxX + 10, gestureFrame.maxX - 20)
                startY = zoomFrame.midY
                XCTAssertTrue(gestureFrame.contains(CGPoint(x: x, y: startY)),
                              "Crop scrolling must begin in visible controls, outside the photo")
            }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            var endY = upward ? bottom : top
            if let viewport {
                let frame = element.frame
                let outside = upward ? viewport.minY - frame.minY : frame.maxY - viewport.maxY
                let travel = min(max(24, outside + 12), viewport.height * 0.6)
                endY = upward ? min(startY + travel, viewport.maxY - 8)
                    : max(startY - travel, viewport.minY + 8)
            }
            let start = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: startY - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: x - app.frame.minX, dy: endY - app.frame.minY))
            print("UI SCROLL \(element.identifier): frame=\(element.frame), viewport=\(gestureFrame), start=(\(x),\(startY)), direction=\(upward ? "toward top" : "toward bottom")")
            // End while holding still, so a small visibility adjustment does
            // not become the fling that previously oscillated behind the photo.
            start.press(forDuration: 0.1, thenDragTo: end, withVelocity: XCUIGestureVelocity(150), thenHoldForDuration: 0.35)
            attempts += 1
        }
        if !isReachable() { failureEvidence(app, named: "unreachable-element") }
        XCTAssertTrue(isReachable(), "Element should be reachable inside its unobscured viewport: \(element)")
    }

    @MainActor
    private func require(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 10) {
        let exists = element.waitForExistence(timeout: timeout)
        if !exists { failureEvidence(app, named: "missing-element") }
        XCTAssertTrue(exists, "Required UI is missing: \(element)")
    }

    @MainActor
    private func waitUntil(in app: XCUIApplication, description: String, timeout: TimeInterval, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        let ready = XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
        if !ready { failureEvidence(app, named: "timed-out-state") }
        XCTAssertTrue(ready, description)
    }

    @MainActor
    private func failureEvidence(_ app: XCUIApplication, named name: String) {
        capture(app, named: name)
        attachHierarchy(app, named: name + "-hierarchy")
    }

    @MainActor
    private func attachHierarchy(_ app: XCUIApplication, named name: String) {
        let hierarchy = app.debugDescription
        print("UI DIAGNOSTIC \(name)\n\(hierarchy)")
        let attachment = XCTAttachment(string: hierarchy)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
