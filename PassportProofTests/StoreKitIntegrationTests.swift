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
        environment.failTransactionsEnabled = true
        environment.failureError = .paymentCancelled
        await store.purchase()
        XCTAssertFalse(store.isUnlocked)
        XCTAssertEqual(store.state, .available)
        XCTAssertFalse(store.isWorking)
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
}
