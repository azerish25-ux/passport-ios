import XCTest
import StoreKit
import StoreKitTest
@testable import PassportProof

/// Real StoreKit Test transactions. These are local simulated purchases, never
/// real-money charges, and do not use the app's debug entitlement bypass.
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private func environment() throws -> SKTestSession {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "PassportProof", withExtension: "storekit"))
        let environment = try SKTestSession(contentsOf: url)
        environment.resetToDefaultState()
        environment.clearTransactions()
        environment.disableDialogs = true
        return environment
    }

    func testPurchaseRestoreAndRefundUpdateVerifiedEntitlement() async throws {
        let environment = try environment()
        // Start from a store with no transaction of its own. A purchase that
        // another test left behind makes `refresh()` legitimately report
        // `.purchased`, which looks like this test's entitlement leaking rather
        // than an environment that was never reset.
        environment.clearTransactions()
        environment.resetToDefaultState()
        defer { environment.clearTransactions(); environment.resetToDefaultState() }
        let store = EntitlementStore()
        await store.refresh()
        XCTAssertEqual(store.state, .available)
        XCTAssertFalse(store.isUnlocked)
        await store.purchase()
        XCTAssertTrue(store.isUnlocked, "The production purchase method must unlock from a verified transaction.")
        XCTAssertFalse(store.isPrototypeUnlock)
        XCTAssertEqual(store.state, .purchased)

        let relaunchedStore = EntitlementStore()
        await relaunchedStore.restore()
        XCTAssertTrue(relaunchedStore.isUnlocked, "A fresh store must recover the purchase without purchasing again.")
        let transaction = try XCTUnwrap(environment.allTransactions().last)
        try environment.refundTransaction(identifier: transaction.identifier)
        try await eventually { !store.isUnlocked }
        await relaunchedStore.refresh()
        XCTAssertFalse(relaunchedStore.isUnlocked, "A revoked non-consumable must not keep export unlocked.")
    }

    func testCancelledPurchaseDoesNotUnlockOrShowFailure() async throws {
        let environment = try environment()
        defer { environment.clearTransactions(); environment.resetToDefaultState() }
        let store = EntitlementStore()
        await store.refresh()
        XCTAssertEqual(store.state, .available)
        // The legacy failureError API does not support paymentCancelled. Using
        // that unsupported code can produce a different failure, not a canceled
        // purchase. Inject the documented StoreKit 2 purchase error instead.
        // https://developer.apple.com/documentation/storekittest/sktestsession/failureerror
        // https://developer.apple.com/documentation/storekittest/sktestsession/setsimulatederror(_:forapi:)
        // https://developer.apple.com/documentation/storekittest/sktestfailures/purchase/generic(_:)
        try await environment.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let configured = await environment.simulatedError(forAPI: .purchase)
        XCTAssertEqual(configured, .generic(.userCancelled))
        await store.purchase()
        recordPurchaseDiagnostic(store, configured: String(describing: configured), name: "cancelled-purchase")
        XCTAssertFalse(store.isUnlocked)
        XCTAssertEqual(store.state, .available, store.lastPurchaseErrorDiagnostic ?? "No error was thrown")
        XCTAssertFalse(store.isWorking)
        XCTAssertFalse(store.isPrototypeUnlock)
    }

    func testNonCancellationPurchaseFailureStaysLockedAndCanRetry() async throws {
        let environment = try environment()
        defer { environment.clearTransactions(); environment.resetToDefaultState() }
        let store = EntitlementStore()
        await store.refresh()
        XCTAssertEqual(store.state, .available)
        try await environment.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        let configuredFailure = await environment.simulatedError(forAPI: .purchase)
        XCTAssertEqual(configuredFailure, .generic(.notAvailableInStorefront))
        await store.purchase()
        recordPurchaseDiagnostic(store, configured: "StoreKitError.notAvailableInStorefront", name: "non-cancellation-purchase")
        XCTAssertFalse(store.isUnlocked)
        XCTAssertFalse(store.isWorking)
        guard case .failed = store.state else {
            return XCTFail("An actual store failure must remain visible: \(store.state)")
        }

        try await environment.setSimulatedError(nil, forAPI: .purchase)
        let clearedBySetter = await environment.simulatedError(forAPI: .purchase)
        print("STOREKIT RETRY simulated error after nil setter: \(String(describing: clearedBySetter))")
        // CI still received an Xcode-forced server failure on the next purchase
        // after the nil setter. Restore all test-server settings as a recovery
        // precondition; keep this same app store and its transaction history.
        // This is not an entitlement reset or an app-side purchase bypass.
        // https://developer.apple.com/documentation/storekittest/sktestsession/resettodefaultstate()
        environment.resetToDefaultState()
        environment.disableDialogs = true
        let retryError = await environment.simulatedError(forAPI: .purchase)
        XCTAssertNil(retryError, "The retry must run without a simulated purchase failure")

        // UnlockView's actual Try again action refreshes product availability
        // before presenting the purchase button again. Exercise that same path.
        await store.refresh()
        XCTAssertEqual(store.state, .available)
        XCTAssertFalse(store.isUnlocked, "Refreshing after failure must not grant an entitlement")
        await store.purchase()
        recordPurchaseDiagnostic(store, configured: String(describing: retryError), name: "purchase-retry-after-failure")
        XCTAssertTrue(store.isUnlocked, "A supported retry must complete through verified StoreKit purchase")
        XCTAssertEqual(store.state, .purchased)
        XCTAssertFalse(store.isPrototypeUnlock)
        XCTAssertNil(store.lastPurchaseErrorDiagnostic, "A successful new attempt must discard stale failure details")
    }

    func testCancellationRecognitionDoesNotHideOtherStoreErrors() {
        let cancelled = NSError(domain: SKErrorDomain, code: SKError.Code.paymentCancelled.rawValue)
        XCTAssertTrue(EntitlementStore.isCancellation(StoreKitError.userCancelled))
        XCTAssertTrue(EntitlementStore.isCancellation(cancelled))
        XCTAssertTrue(EntitlementStore.isCancellation(StoreKitError.systemError(cancelled)))
        let wrapped = NSError(domain: "Test.StoreWrapper", code: 1,
                              userInfo: [NSUnderlyingErrorKey: StoreKitError.systemError(cancelled)])
        XCTAssertTrue(EntitlementStore.isCancellation(wrapped))

        XCTAssertFalse(EntitlementStore.isCancellation(StoreKitError.unknown))
        XCTAssertFalse(EntitlementStore.isCancellation(StoreKitError.networkError(URLError(.cancelled))))
        XCTAssertFalse(EntitlementStore.isCancellation(StoreKitError.systemError(URLError(.notConnectedToInternet))))
        let invalidPayment = NSError(domain: SKErrorDomain, code: SKError.Code.paymentInvalid.rawValue,
                                     userInfo: [NSUnderlyingErrorKey: cancelled])
        XCTAssertFalse(EntitlementStore.isCancellation(StoreKitError.systemError(invalidPayment)))
        XCTAssertFalse(EntitlementStore.isCancellation(NSError(domain: "Test.Unrelated", code: cancelled.code,
                                                              userInfo: [NSLocalizedDescriptionKey: "Payment canceled"])))
        var deeplyWrapped: Error = cancelled
        for _ in 0..<12 {
            deeplyWrapped = NSError(domain: "Test.StoreWrapper", code: 1, userInfo: [NSUnderlyingErrorKey: deeplyWrapped])
        }
        XCTAssertFalse(EntitlementStore.isCancellation(deeplyWrapped), "Error-chain inspection must have a finite bound")
    }

    func testPendingPurchaseStaysLockedUntilApproval() async throws {
        let environment = try environment()
        defer { environment.clearTransactions(); environment.resetToDefaultState() }
        environment.askToBuyEnabled = true
        let store = EntitlementStore()
        await store.refresh()
        await store.purchase()
        XCTAssertEqual(store.state, .pending)
        XCTAssertFalse(store.isUnlocked)
        let pending = try XCTUnwrap(environment.allTransactions().last)
        try environment.approveAskToBuyTransaction(identifier: pending.identifier)
        try await eventually { store.isUnlocked }
        XCTAssertFalse(store.isPrototypeUnlock)
    }

    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        for _ in 0..<60 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(condition(), "StoreKit transaction update did not reach the app.", file: file, line: line)
    }

    private func recordPurchaseDiagnostic(_ store: EntitlementStore, configured: String, name: String) {
        let summary = """
        Configured error: \(configured)
        Resulting state: \(store.state)
        Unlocked: \(store.isUnlocked); working: \(store.isWorking)
        Thrown error chain:
        \(store.lastPurchaseErrorDiagnostic ?? "No thrown error; StoreKit returned a PurchaseResult")
        """
        print("STOREKIT DIAGNOSTIC \(name)\n\(summary)")
        let attachment = XCTAttachment(string: summary)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
