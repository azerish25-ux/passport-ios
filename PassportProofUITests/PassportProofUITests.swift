//
//  PassportProofUITests.swift
//  PassportProofUITests
//
//  The suite asserts user-visible outcomes, not pixel travel. Two inputs are
//  deliberately controlled:
//
//    * the photo, through the DEBUG-only `-UITestSeedPhoto` launch argument, so
//      a test does not depend on PhotoKit's virtual grid or on the simulator
//      detecting a face (which it currently does not do reliably);
//    * the store, through Apple's local StoreKit Test transactions.
//
//  Nothing here charges money, and no production entitlement bypass exists.
//  One test still opens the real system photo picker to prove the import path
//  is wired; it does not depend on selecting an asset.
//

import XCTest
import StoreKitTest

final class PassportProofUITests: XCTestCase {
    private let unlimitedIdentifier = "com.passportproof.app.unlock"
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
            testedApp?.terminate()
            testedApp = nil
        }
        storeSession?.clearTransactions()
        storeSession = nil
        try await super.tearDown()
    }

    // MARK: - Catalogue

    @MainActor
    func testLibraryListsEverySupportedWorkflow() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["library.start"].exists)
        for identifier in [
            "us-passport", "us-visa", "us-dv-lottery", "ca-passport", "de-schengen-visa"
        ] {
            XCTAssertTrue(app.buttons["library.document.\(identifier)"].exists,
                          "The catalogue must list \(identifier)")
        }
        XCTAssertTrue(app.buttons["library.privacy"].exists)
        XCTAssertTrue(app.buttons["library.unlock"].exists)
        capture(app, named: "01-library")
    }

    @MainActor
    func testPrivacyDisclosureExplainsLocalProcessing() {
        let app = launchApp()
        app.buttons["library.privacy"].tap()
        require(app.staticTexts["Private by design"], in: app)
        XCTAssertTrue(app.staticTexts["Photos"].exists)
        XCTAssertTrue(app.staticTexts["Data collection"].exists)
        capture(app, named: "02-privacy")
    }

    @MainActor
    func testDocumentDetailLeadsToPhotoSources() {
        let app = launchApp()
        openCapture(in: app, documentID: "us-visa")
        XCTAssertTrue(app.buttons["capture.camera"].exists)
        XCTAssertTrue(app.buttons["capture.library"].exists)
        XCTAssertFalse(app.buttons["capture.camera"].isEnabled,
                       "A simulator without camera hardware must offer import instead")
        XCTAssertTrue(app.buttons["capture.library"].isEnabled)
        capture(app, named: "03-capture-sources")
    }

    @MainActor
    func testSystemPhotoPickerOpens() {
        let app = launchApp()
        openCapture(in: app, documentID: "us-visa")
        app.buttons["capture.library"].tap()
        // The picker is system UI; assert it is presented and dismissable, not
        // that a particular virtual grid cell can be tapped.
        let photos = app.navigationBars["Photos"]
        require(photos, in: app, timeout: 45)
        capture(app, named: "03-photos-picker")
        let cancel = photos.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 10) {
            cancel.tap()
        } else {
            // Some runtimes present the picker without a Cancel button in the
            // navigation bar; a downward swipe dismisses the sheet.
            app.swipeDown()
        }
        require(app.buttons["capture.library"], in: app, timeout: 20)
    }

    // MARK: - Store

    @MainActor
    func testUnlimitedPurchaseSurvivesRelaunchAndRestores() {
        let app = launchApp()
        openUnlock(in: app)
        let purchase = app.buttons["unlock.purchase"]
        require(purchase, in: app, timeout: 25)
        scrollTo(purchase, in: app)
        XCTAssertTrue(storeSession.allTransactions().isEmpty)
        capture(app, named: "04-unlock")
        purchase.tap()

        waitUntil(in: app, description: "The purchase must create a StoreKit transaction", timeout: 30) {
            !self.storeSession.allTransactions().isEmpty
        }
        // UnlockView dismisses only after the production store verifies the
        // transaction; the debug demonstration action is never used here.
        require(app.buttons["library.privacy"], in: app, timeout: 25)
        capture(app, named: "04-purchased")

        app.terminate()
        app.launch()
        require(app.buttons["library.privacy"], in: app, timeout: 25)
        openUnlock(in: app)
        require(app.staticTexts["Export is unlocked for this Apple Account."], in: app, timeout: 25)
        XCTAssertFalse(app.buttons["unlock.purchase"].exists,
                       "A fresh process must recover the verified non-consumable")
        let restore = app.buttons["unlock.restore"]
        scrollTo(restore, in: app)
        restore.tap()
        waitUntil(in: app, description: "Restore must finish without another purchase", timeout: 25) {
            restore.isEnabled
        }
        XCTAssertEqual(storeSession.allTransactions().count, 1)
    }

    // MARK: - Full digital journey

    @MainActor
    func testSeededPhotoManualFramingAndDigitalExport() throws {
        try storeSession.buyProduct(productIdentifier: unlimitedIdentifier)
        let app = launchApp(seededDocument: "us-visa")
        openCapture(in: app, documentID: "us-visa")
        startReview(in: app)

        XCTAssertTrue(app.staticTexts["analysis.automaticUnavailable"].exists,
                      "The synthetic original must not be reported as automatically measured")
        capture(app, named: "05-analysis-unavailable")
        completeManualFraming(in: app, evidencePrefix: "05")
        confirmVisualReview(in: app)

        let next = app.buttons["analysis.continue"]
        scrollTo(next, in: app)
        waitUntil(in: app, description: "Manual framing plus review must enable export", timeout: 15) {
            next.isEnabled
        }
        next.tap()
        let disclosure = app.alerts["Review the unverified checks"]
        require(disclosure, in: app)
        capture(app, named: "05-disclosure")
        disclosure.buttons["Continue to export"].tap()

        let export = app.buttons["export.primary"]
        require(export, in: app, timeout: 20)
        waitUntil(in: app, description: "The export action must become available", timeout: 15) {
            export.isEnabled
        }
        XCTAssertEqual(export.label, "Export JPEG")
        XCTAssertTrue(app.staticTexts["export.manualStatus"].exists)
        capture(app, named: "05-digital-export")
        export.tap()
        requireShareSheet(in: app)
        capture(app, named: "05-share-sheet")
    }

    // MARK: - Full print journey

    @MainActor
    func testSeededPhotoPassportPrintLayoutsAndPDFExport() throws {
        try storeSession.buyProduct(productIdentifier: unlimitedIdentifier)
        let app = launchApp(seededDocument: "us-passport")
        openCapture(in: app, documentID: "us-passport")
        startReview(in: app)
        completeManualFraming(in: app, evidencePrefix: "06")
        confirmVisualReview(in: app)

        let next = app.buttons["analysis.continue"]
        scrollTo(next, in: app)
        waitUntil(in: app, description: "The reviewed passport must permit export", timeout: 15) {
            next.isEnabled
        }
        next.tap()
        let disclosure = app.alerts["Review the unverified checks"]
        require(disclosure, in: app)
        disclosure.buttons["Continue to export"].tap()

        let export = app.buttons["export.primary"]
        require(export, in: app, timeout: 20)
        XCTAssertEqual(export.label, "Export PDF")
        XCTAssertTrue(app.buttons["export.calibration"].exists)

        // A 2 × 2 inch photo fills the same grids these sheets were designed
        // around, so the counts are exact and stable.
        let expected = [
            ("fourBySix", "4 × 6 in", 4),
            ("fiveBySeven", "5 × 7 in", 6)
        ]
        for (identifier, title, copies) in expected {
            let choice = app.buttons["layout.\(identifier)"]
            scrollTo(choice, in: app)
            choice.tap()
            waitUntil(in: app, description: "\(title) must become the selected sheet", timeout: 10) {
                choice.isSelected
            }
            let caption = app.staticTexts["\(title) · \(copies) photos · print at 100%"]
            require(caption, in: app, timeout: 20)
            capture(app, named: "06-print-\(identifier)")
        }

        scrollTo(export, in: app, towardTop: true)
        export.tap()
        requireShareSheet(in: app)
        capture(app, named: "06-pdf-share-sheet")
    }

    // MARK: - Appearance

    @MainActor
    func testDarkModeAndAccessibilityText() {
        let dark = launchApp(arguments: ["-UITestDarkMode"])
        capture(dark, named: "07-library-dark")
        openCapture(in: dark, documentID: "us-visa")
        capture(dark, named: "07-capture-dark")
        dark.terminate()

        let large = launchApp(arguments: ["-UITestLargeText"])
        require(large.buttons["library.start"], in: large)
        capture(large, named: "07-library-large-text")
    }

    // MARK: - Flow helpers

    @MainActor
    private func startReview(in app: XCUIApplication) {
        let review = app.buttons["capture.review"]
        require(review, in: app, timeout: 20)
        scrollTo(review, in: app)
        review.tap()
        require(app.images["analysis.photo"], in: app, timeout: 45)
    }

    @MainActor
    private func completeManualFraming(in app: XCUIApplication, evidencePrefix: String) {
        let entry = app.buttons["analysis.manualStart"]
        require(entry, in: app, timeout: 20)
        entry.tap()
        require(app.images["manual.preview"], in: app, timeout: 20)

        // The suggested guides are derived from this document's published
        // ranges and are valid by construction; they still grant nothing until
        // every attestation is switched on explicitly.
        let save = app.buttons["manual.confirm"]
        XCTAssertFalse(save.isEnabled, "Suggested guides must never grant approval")
        for identifier in [
            "manual.review.guides", "manual.review.face",
            "manual.review.background", "manual.review.limitations"
        ] {
            switchOn(identifier, in: app, description: "Manual attestation must persist")
        }
        waitUntil(in: app, description: "All four attestations must enable saving", timeout: 8) {
            save.isEnabled
        }
        capture(app, named: "\(evidencePrefix)-manual-framing")
        save.tap()
        require(app.staticTexts["analysis.manualStatus"], in: app, timeout: 20)
    }

    @MainActor
    private func confirmVisualReview(in app: XCUIApplication) {
        for identifier in ["review.expression", "review.glasses", "review.recent", "review.original"] {
            switchOn(identifier, in: app, description: "The visual confirmation must persist")
        }
    }

    /// Switches one confirmation on and insists that it stayed on.
    ///
    /// A SwiftUI `Toggle` reports its whole row as one element, so `tap()` aims
    /// at the middle of a two-line label — which does not move the switch. The
    /// tap is therefore aimed at the control at the trailing edge, and retried,
    /// because a tap delivered while the scroll view is still decelerating is
    /// consumed by the scroll. The assertion is unchanged: the switch has to
    /// end up on.
    @MainActor
    private func switchOn(_ identifier: String, in app: XCUIApplication, description: String) {
        let toggle = app.switches[identifier]
        scrollTo(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0", "\(identifier) must start switched off")
        for _ in 0..<3 {
            if !toggle.isHittable { scrollTo(toggle, in: app) }
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            if waitForSwitch(toggle, on: true, timeout: 4) { return }
        }
        capture(app, named: "switch-\(identifier)")
        XCTFail("\(description): \(identifier). On screen: \(visibleIdentifiers(app))")
    }

    @MainActor
    private func waitForSwitch(_ toggle: XCUIElement, on: Bool, timeout: TimeInterval) -> Bool {
        let expected = on ? "1" : "0"
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if (toggle.value as? String) == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline
        return (toggle.value as? String) == expected
    }

    @MainActor
    private func requireShareSheet(in app: XCUIApplication) {
        waitUntil(in: app, description: "A generated file must reach the system share sheet", timeout: 30) {
            app.buttons["Save to Files"].exists || app.buttons["Copy"].exists
                || app.otherElements["ActivityListView"].exists
        }
    }

    // MARK: - Navigation

    @MainActor
    private func launchApp(arguments: [String] = [], seededDocument: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        var launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + arguments
        if let seededDocument {
            launchArguments += ["-UITestSeedPhoto", seededDocument]
        }
        app.launchArguments = launchArguments
        testedApp = app
        app.launch()
        require(app.buttons["library.privacy"], in: app, timeout: 25)
        return app
    }

    @MainActor
    private func openCapture(in app: XCUIApplication, documentID: String) {
        let document = app.buttons["library.document.\(documentID)"]
        scrollTo(document, in: app)
        document.tap()
        let measure = app.buttons["detail.measure"]
        scrollTo(measure, in: app)
        measure.tap()
        require(app.buttons["capture.library"], in: app, timeout: 20)
    }

    @MainActor
    private func openUnlock(in app: XCUIApplication) {
        let unlock = app.buttons["library.unlock"]
        scrollTo(unlock, in: app)
        unlock.tap()
        require(app.descendants(matching: .any)["unlock.purchaseArea"], in: app, timeout: 20)
    }

    // MARK: - Assertions and evidence

    /// Scrolls in bounded steps until the element is hittable.
    ///
    /// The drag starts on the 20 pt horizontal page margin rather than in the
    /// middle of the screen. A drag that begins on a slider is consumed by that
    /// slider, so the scroll view never moves — which is exactly how the framing
    /// attestations became unreachable in the previous run.
    @MainActor
    private func scrollTo(_ element: XCUIElement, in app: XCUIApplication, towardTop: Bool = false) {
        require(element, in: app)
        var attempts = 0
        while !(element.exists && element.isHittable) && attempts < 10 {
            dragInGutter(in: app, towardTop: towardTop)
            attempts += 1
        }
        if !element.isHittable {
            capture(app, named: "unreachable-\(element.identifier.isEmpty ? "element" : element.identifier)")
            XCTFail("Element never became hittable: \(element) after \(attempts) drags. On screen: \(visibleIdentifiers(app))")
        }
    }

    @MainActor
    private func dragInGutter(in app: XCUIApplication, towardTop: Bool) {
        let gutter = 0.955
        let lower = 0.78
        let upper = 0.30
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: gutter, dy: towardTop ? upper : lower))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: gutter, dy: towardTop ? lower : upper))
        start.press(forDuration: 0.05, thenDragTo: end,
                    withVelocity: XCUIGestureVelocity(300), thenHoldForDuration: 0.1)
        // Let the scroll view settle before anything taps inside it; a tap
        // delivered mid-momentum is consumed by the scroll.
        Thread.sleep(forTimeInterval: 0.2)
    }

    @MainActor
    private func require(_ element: XCUIElement, in app: XCUIApplication, timeout: TimeInterval = 15) {
        if !element.waitForExistence(timeout: timeout) {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "missing-\(element.identifier.isEmpty ? "element" : element.identifier)"
            attachment.lifetime = .keepAlways
            add(attachment)
            print("UI DIAGNOSTIC hierarchy\n\(app.debugDescription)")
        }
        // The failure message travels into the CI annotation, where the
        // screenshot and hierarchy in the artifact cannot be read. Naming the
        // identifiers that were on screen distinguishes "wrong screen" from
        // "right screen, element not built yet" without another run.
        XCTAssertTrue(element.exists, "Required UI is missing: \(element). On screen: \(visibleIdentifiers(app))")
    }

    /// Identifiers of the elements present right now, bounded so a failure
    /// message stays readable in an annotation.
    @MainActor
    private func visibleIdentifiers(_ app: XCUIApplication) -> String {
        let identifiers = app.descendants(matching: .any).allElementsBoundByIndex
            .map(\.identifier)
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        let unique = identifiers.filter { seen.insert($0).inserted }
        if unique.isEmpty { return "(no identifiers)" }
        return unique.prefix(25).joined(separator: ", ")
    }

    @MainActor
    private func waitUntil(in app: XCUIApplication, description: String, timeout: TimeInterval, condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        let completed = XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
        if !completed {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "timed-out-state"
            attachment.lifetime = .keepAlways
            add(attachment)
            print("UI DIAGNOSTIC hierarchy at timeout\n\(app.debugDescription)")
        }
        XCTAssertTrue(completed, "\(description). On screen: \(visibleIdentifiers(app))")
    }

    @MainActor
    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
