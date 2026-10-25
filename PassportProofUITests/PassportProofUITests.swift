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

    override func tearDownWithError() throws {
        testedApp?.terminate()
        testedApp = nil
        storeSession?.clearTransactions()
        storeSession = nil
        try super.tearDownWithError()
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
    func testRealPhotoImportReviewCanceledEditAndDigitalShare() throws {
        executionTimeAllowance = 300
        // This transaction uses Apple's local StoreKit environment. The separate
        // purchase test above exercises the application's purchase button.
        try storeSession.buyProduct(productIdentifier: productIdentifier)
        let app = launchApp()
        openCapture(in: app)
        importSeededPortrait(in: app)

        let confirmCrop = app.buttons["crop.confirm"]
        require(confirmCrop, in: app, timeout: 30)
        waitUntil(in: app, description: "The original photo must finish preparing", timeout: 30) { confirmCrop.isEnabled }
        capture(app, named: "08-real-photo-crop")
        confirmCrop.tap()

        let photo = app.images["analysis.photo"]
        require(photo, in: app, timeout: 40)
        capture(app, named: "08-real-photo-analysis")
        attachHierarchy(app, named: "08-real-analysis-findings")

        let reviewIDs = confirmVisualReview(in: app)

        // A draft rotation/reset must not destroy the accepted photo or its
        // completed review when the user cancels. Session unit tests additionally
        // verify original pixel retention and accepted-crop revision isolation.
        let edit = app.buttons["analysis.editCrop"]
        scrollToHittable(edit, in: app, towardTop: true)
        edit.tap()
        require(app.buttons["crop.cancel"], in: app)
        waitUntil(in: app, description: "The retained original must reopen for editing", timeout: 30) {
            app.buttons["crop.confirm"].isEnabled
        }
        let rotate = app.buttons["crop.rotate"]
        scrollToHittable(rotate, in: app)
        rotate.tap()
        waitUntil(in: app, description: "Rotation must finish", timeout: 30) { app.buttons["crop.reset"].isEnabled }
        app.buttons["crop.reset"].tap()
        waitUntil(in: app, description: "Reset must finish", timeout: 30) { app.buttons["crop.confirm"].isEnabled }

        // Check lifecycle preservation through public UI operations. A distinct
        // draft zoom makes a silently recreated editor observable. This does not
        // inspect or make claims about the system's private app-switcher image.
        let zoom = app.sliders["crop.zoom"]
        scrollToHittable(zoom, in: app, towardTop: true)
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
        for identifier in reviewIDs {
            XCTAssertEqual(app.switches[identifier].value as? String, "1", "Canceling a crop must preserve the accepted photo's review")
        }

        let next = app.buttons["analysis.continue"]
        // A genuine detected failure is a failed regression with its findings
        // attached, never a skipped test or a fabricated passing analysis.
        require(next, in: app, timeout: 10)
        waitUntil(in: app, description: "The actual fixture findings must allow export after human review", timeout: 10) { next.isEnabled }
        next.tap()
        let uncertain = app.alerts["Review the uncertain measurements"]
        if uncertain.waitForExistence(timeout: 2) {
            capture(app, named: "08-uncertain-measurements-disclosure")
            uncertain.buttons["Continue to export"].tap()
        }

        let export = app.buttons["export.primary"]
        require(export, in: app, timeout: 15)
        XCTAssertEqual(export.label, "Export JPEG", "The verified purchase and real review must unlock the digital export")
        XCTAssertTrue(app.descendants(matching: .any)["export.preview"].exists)
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
    func testRealPassportPhotoPrintLayoutsAndPDFShare() throws {
        executionTimeAllowance = 300
        try storeSession.buyProduct(productIdentifier: productIdentifier)
        let app = launchApp()
        openCapture(in: app, documentID: "us-passport")
        importSeededPortrait(in: app, evidencePrefix: "09")

        let confirmCrop = app.buttons["crop.confirm"]
        require(confirmCrop, in: app, timeout: 30)
        waitUntil(in: app, description: "The passport crop must finish preparing", timeout: 30) { confirmCrop.isEnabled }
        capture(app, named: "09-passport-crop")
        confirmCrop.tap()
        require(app.images["analysis.photo"], in: app, timeout: 40)
        capture(app, named: "09-passport-analysis")
        attachHierarchy(app, named: "09-real-passport-findings")
        confirmVisualReview(in: app)

        let next = app.buttons["analysis.continue"]
        require(next, in: app, timeout: 10)
        waitUntil(in: app, description: "The real passport findings and confirmations must permit export", timeout: 10) { next.isEnabled }
        next.tap()
        let uncertain = app.alerts["Review the uncertain measurements"]
        if uncertain.waitForExistence(timeout: 2) {
            capture(app, named: "09-passport-review-disclosure")
            uncertain.buttons["Continue to export"].tap()
        }

        let export = app.buttons["export.primary"]
        require(export, in: app, timeout: 15)
        XCTAssertEqual(export.label, "Export PDF", "The reviewed passport crop and verified purchase must enable PDF export")
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
            scrollToHittable(app.staticTexts["Choose your paper"], in: app)
            let choice = app.buttons["layout.\(layout.identifier)"]
            scrollToHittable(choice, in: app)
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
            scrollToHittable(preview, in: app, towardTop: true)
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
        require(photosNavigation, in: app, timeout: 20)
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
        let assetFrame = portrait.frame
        print("PHOTOS PICKER selecting newest asset: \(portrait.label); frame=\(assetFrame); isHittable=\(portrait.isHittable); pickerFrame=\(picker.frame)")
        attachHierarchy(app, named: "\(evidencePrefix)-system-photos-picker")
        capture(app, named: "\(evidencePrefix)-photos-picker")
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: assetFrame.midX - app.frame.minX,
            dy: assetFrame.midY - app.frame.minY
        )).tap()
        require(app.buttons["crop.confirm"], in: app, timeout: 30)
    }

    @MainActor
    @discardableResult
    private func confirmVisualReview(in app: XCUIApplication) -> [String] {
        // These interactions exercise required human confirmations; they do not
        // certify that the public QA portrait is an accepted application photo.
        let identifiers = ["review.expression", "review.glasses", "review.recent", "review.original"]
        for identifier in identifiers {
            let toggle = app.switches[identifier]
            scrollToHittable(toggle, in: app)
            XCTAssertEqual(toggle.value as? String, "0")
            toggle.tap()
            waitUntil(in: app, description: "The visual confirmation must persist: \(identifier)", timeout: 5) {
                toggle.value as? String == "1"
            }
        }
        return identifiers
    }

    @MainActor
    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        require(element, in: app)
        var attempts = 0
        while !element.isHittable && attempts < 9 {
            // The crop preview owns its drag gesture. Scroll in the outer
            // padding so reaching its controls never reframes the photograph.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: towardTop ? 0.32 : 0.72))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: towardTop ? 0.72 : 0.32))
            start.press(forDuration: 0.05, thenDragTo: end)
            attempts += 1
        }
        if !element.isHittable { failureEvidence(app, named: "unreachable-element") }
        XCTAssertTrue(element.isHittable, "Element should be reachable by scrolling: \(element)")
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
