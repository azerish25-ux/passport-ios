//
//  PassportProofUITests.swift
//  PassportProofUITests
//
//  Simulator smoke coverage and visual evidence. These tests do not depend on
//  camera hardware, photo access or a live App Store purchase.
//

import XCTest

final class PassportProofUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLibraryCatalogueAndPrimaryAction() {
        let app = launchApp()

        XCTAssertTrue(app.buttons["library.start"].exists)
        XCTAssertTrue(app.buttons["library.document.us-passport"].exists)
        XCTAssertTrue(app.buttons["library.document.us-visa"].exists)
        XCTAssertTrue(app.buttons["library.document.us-dv-lottery"].exists)
        XCTAssertTrue(app.buttons["library.privacy"].exists)

        capture(app, named: "01-library")
    }

    func testLibraryRemainsActionableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["library.start"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["library.privacy"].isHittable)
        capture(app, named: "05-library-accessibility-text")
    }

    func testPrivacyDisclosureOpensFromLibrary() {
        let app = launchApp()
        app.buttons["library.privacy"].tap()

        XCTAssertTrue(app.staticTexts["Private by design"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Photos"].exists)
        XCTAssertTrue(app.staticTexts["Data collection"].exists)
        capture(app, named: "02-privacy")
    }

    func testDocumentDetailLeadsToCaptureSources() {
        let app = launchApp()
        let document = app.buttons["library.document.us-visa"]
        scrollToHittable(document, in: app)
        document.tap()

        let measure = app.buttons["detail.measure"]
        scrollToHittable(measure, in: app)
        measure.tap()

        XCTAssertTrue(app.buttons["capture.camera"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["capture.library"].exists)
        capture(app, named: "03-capture-sources")
    }

    func testLibraryUnlockRouteShowsPurchaseArea() {
        let app = launchApp()
        let unlock = app.buttons["library.unlock"]
        scrollToHittable(unlock, in: app)
        unlock.tap()

        let purchaseArea = app.descendants(matching: .any)["unlock.purchaseArea"]
        XCTAssertTrue(purchaseArea.waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["Export unlock"].exists)
        capture(app, named: "04-unlock")
    }

    // MARK: - Helpers

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(
            app.buttons["library.start"].waitForExistence(timeout: 20),
            "The library did not finish launching"
        )
        return app
    }

    private func scrollToHittable(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 8))
        var attempts = 0
        while !element.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.isHittable, "Element should be reachable by scrolling: \(element)")
    }

    private func capture(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
