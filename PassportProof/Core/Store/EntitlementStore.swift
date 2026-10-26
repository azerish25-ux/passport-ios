//
//  EntitlementStore.swift
//  PassportProof
//
//  StoreKit 2, no server. Two products:
//
//    * an unlimited non-consumable, recomputed from verified current
//      transactions on launch, restore and every live update;
//    * a single-export consumable, credited only from a verified transaction.
//
//  The consumable exists because a passport photo is a once-a-year need. Asking
//  every customer for the unlimited price up front loses the majority of them;
//  a low-commitment single export converts, and the unlimited option is the
//  obvious better value beside it. Export credits are local to this device: a
//  consumable cannot be restored by Apple, and the paywall says so rather than
//  implying otherwise.
//
//  The demonstration bypass exists only in DEBUG and has no Release symbol.
//

import Foundation
import Combine
import StoreKit

enum EntitlementState: Equatable, Sendable {
    case loading
    case available
    case purchased
    case pending
    case unavailable(String)
    case failed(String)
}

/// The two ways to pay. Identifiers are stable: changing one would orphan
/// existing purchases and break restore.
enum ExportProduct: String, CaseIterable, Identifiable, Sendable {
    case unlimited
    case singleExport

    var id: String { rawValue }

    var productIdentifier: String {
        switch self {
        case .unlimited: return "com.passportproof.app.unlock"
        case .singleExport: return "com.passportproof.app.single-export"
        }
    }
}

@MainActor
final class EntitlementStore: ObservableObject {
    /// Retained for existing tests, the release audit and restore compatibility.
    static let productIdentifier = ExportProduct.unlimited.productIdentifier
    static let singleExportIdentifier = ExportProduct.singleExport.productIdentifier

    /// Shown only while StoreKit metadata is unavailable. The App Store is the
    /// source of truth; these are never presented as a live price.
    static let fallbackPrice = "$7.99"
    static let fallbackSinglePrice = "$3.99"

    @Published private(set) var isUnlocked = false
    @Published private(set) var displayPrice = EntitlementStore.fallbackPrice
    @Published private(set) var singleExportPrice: String? = EntitlementStore.fallbackSinglePrice
    @Published private(set) var exportCredits: Int
    @Published private(set) var state: EntitlementState = .loading
    @Published private(set) var isWorking = false
    @Published private(set) var isPrototypeUnlock = false
    @Published private(set) var purchasingProduct: ExportProduct?

    /// Session-only diagnostics for a failed attempt. Contains error types,
    /// domains and codes, never descriptions, account data or full userInfo.
    private(set) var lastPurchaseErrorDiagnostic: String?

    private var unlimitedProduct: Product?
    private var singleProduct: Product?
    private var transactionUpdatesTask: Task<Void, Never>?

    private static let creditsKey = "passportproof.exportCredits.v1"
    private static let grantedKey = "passportproof.grantedConsumables.v1"
    private static let grantedLimit = 200

    /// Consumable transaction IDs that have already produced a credit. Apple
    /// can deliver the same finished transaction through `Transaction.updates`
    /// after the direct purchase result, so granting without this would double
    /// the credit for one payment.
    private var grantedTransactionIDs: Set<UInt64>

    /// True when the customer may export: unlimited purchased, or a verified
    /// single-export credit is available.
    var canExport: Bool { isUnlocked || exportCredits > 0 }

    var canBuySingleExport: Bool { singleProduct != nil }

    init() {
        let defaults = UserDefaults.standard
        exportCredits = max(0, defaults.integer(forKey: Self.creditsKey))
        let stored = defaults.array(forKey: Self.grantedKey) as? [NSNumber] ?? []
        grantedTransactionIDs = Set(stored.map { $0.uint64Value })

        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }
                switch transaction.productID {
                case Self.productIdentifier:
                    let entitled = await self.refreshEntitlements()
                    if entitled { self.state = .purchased }
                    else if self.unlimitedProduct != nil { self.state = .available }
                    else { self.state = .unavailable("The store is unavailable. Refresh to try again.") }
                    await transaction.finish()
                case Self.singleExportIdentifier:
                    self.grantConsumable(transaction)
                    await transaction.finish()
                default:
                    continue
                }
            }
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    // MARK: - Loading

    func refresh() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        state = .loading

        // Local verified entitlements work offline. Check them before asking the
        // network for product metadata so a purchased user is never downgraded
        // by a connection failure.
        let alreadyEntitled = await refreshEntitlements()
        if alreadyEntitled { state = .purchased }

        do {
            let products = try await Product.products(for: [
                Self.productIdentifier,
                Self.singleExportIdentifier
            ])
            unlimitedProduct = products.first { $0.id == Self.productIdentifier }
            singleProduct = products.first { $0.id == Self.singleExportIdentifier }

            if let unlimited = unlimitedProduct {
                displayPrice = unlimited.displayPrice
            } else {
                displayPrice = Self.fallbackPrice
            }
            singleExportPrice = singleProduct?.displayPrice

            if !isUnlocked {
                if unlimitedProduct == nil {
                    #if DEBUG
                    state = .unavailable("StoreKit has no product configured. A debug-only demonstration unlock is available.")
                    #else
                    state = .unavailable("The one-time unlock is not available yet. Check your connection and try again shortly.")
                    #endif
                } else {
                    state = .available
                }
            }
        } catch {
            if isUnlocked {
                state = .purchased
            } else {
                state = .failed(Self.message(for: error))
            }
        }
    }

    // MARK: - Purchase

    /// Buys the unlimited non-consumable. Kept parameterless so the existing
    /// integration tests and any future restore-only caller stay stable.
    func purchase() async {
        guard !isWorking else { return }
        guard let unlimitedProduct else {
            state = .unavailable("The one-time unlock is not available yet. Try again shortly.")
            return
        }

        isWorking = true
        purchasingProduct = .unlimited
        lastPurchaseErrorDiagnostic = nil
        let watchdog = startPurchaseWatchdog()
        defer {
            watchdog.cancel()
            isWorking = false
            purchasingProduct = nil
        }

        do {
            let result = try await unlimitedProduct.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    isUnlocked = true
                    isPrototypeUnlock = false
                    state = .purchased
                    await transaction.finish()
                case .unverified(_, _):
                    state = .failed("The purchase could not be verified on this device. Nothing was unlocked.")
                }
            case .userCancelled:
                state = isUnlocked ? .purchased : .available
            case .pending:
                state = .pending
            @unknown default:
                state = .available
            }
        } catch {
            lastPurchaseErrorDiagnostic = Self.purchaseErrorDiagnostic(error)
            if Self.isCancellation(error) {
                state = isUnlocked ? .purchased : .available
            } else {
                state = .failed(Self.message(for: error))
            }
        }
    }

    /// Buys one export credit. The credit is granted only from a verified
    /// transaction; a pending or unverified purchase grants nothing.
    func purchaseSingleExport() async {
        guard !isWorking else { return }
        guard let singleProduct else {
            state = .unavailable("Single-export purchases are not available right now.")
            return
        }

        isWorking = true
        purchasingProduct = .singleExport
        lastPurchaseErrorDiagnostic = nil
        let watchdog = startPurchaseWatchdog()
        defer {
            watchdog.cancel()
            isWorking = false
            purchasingProduct = nil
        }

        do {
            let result = try await singleProduct.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    grantConsumable(transaction)
                    await transaction.finish()
                    // The customer stays in the store view only if the credit
                    // could not be granted; the view dismisses on credit change.
                    if state != .purchased { state = .available }
                case .unverified(_, _):
                    state = .failed("The purchase could not be verified on this device. Nothing was unlocked.")
                }
            case .userCancelled:
                state = isUnlocked ? .purchased : .available
            case .pending:
                state = .pending
            @unknown default:
                state = .available
            }
        } catch {
            lastPurchaseErrorDiagnostic = Self.purchaseErrorDiagnostic(error)
            if Self.isCancellation(error) {
                state = isUnlocked ? .purchased : .available
            } else {
                state = .failed(Self.message(for: error))
            }
        }
    }

    /// Called only after a file has actually been staged for sharing, so a
    /// failed export never costs a credit. Unlimited accounts are never
    /// decremented.
    @discardableResult
    func consumeExportCredit() -> Bool {
        if isUnlocked { return true }
        guard exportCredits > 0 else { return false }
        exportCredits -= 1
        persistCredits()
        return true
    }

    // MARK: - Restore

    /// `AppStore.sync()` keeps waiting on the App Store account with no deadline
    /// of its own and does not honour cancellation. On a device with no
    /// signed-in account, or during an App Store outage, it can wait for
    /// minutes: the paywall's restore button stays disabled behind "Contacting
    /// App Store…" and the customer is left with no way forward. The wait is
    /// bounded so the screen can always reach a retryable state. Shortened in
    /// tests.
    static var restoreTimeout: Duration = .seconds(25)

    /// `Product.purchase()` has the same open-ended wait. If the store never
    /// answers, the paywall's button was disabled forever with no explanation.
    /// A watchdog releases the screen; a late success still unlocks normally.
    static var purchaseTimeout: Duration = .seconds(30)

    @MainActor
    private func startPurchaseWatchdog() -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: Self.purchaseTimeout)
            guard !Task.isCancelled, let self, self.purchasingProduct != nil else { return }
            self.isWorking = false
            self.purchasingProduct = nil
            self.state = .failed("The App Store did not answer in time. Nothing was charged. Check your connection, then try again.")
        }
    }

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        if await refreshEntitlements() {
            state = .purchased
            return
        }

        switch await Self.syncAppStoreAccount(timeout: Self.restoreTimeout) {
        case .success:
            if await refreshEntitlements() {
                state = .purchased
            } else {
                state = .failed("No previous PassportProof purchase was found for this Apple Account.")
            }
        case .failure(.timedOut):
            state = .failed("The App Store did not respond in time. Check your connection, then try again.")
        case .failure(.thrown(let error)):
            state = .failed(Self.message(for: error))
        }
    }

    /// Races the account sync against a deadline. The losing side is abandoned
    /// rather than awaited: awaiting a cancelled `AppStore.sync()` call would
    /// reintroduce the unbounded wait this exists to remove.
    nonisolated private static func syncAppStoreAccount(timeout: Duration) async -> Result<Void, AccountSyncOutcome> {
        let sync = Task.detached(priority: .userInitiated) { () -> Result<Void, AccountSyncOutcome> in
            do {
                try await AppStore.sync()
                return .success(())
            } catch {
                return .failure(.thrown(error))
            }
        }
        return await withCheckedContinuation { continuation in
            let gate = ContinuationGate()
            Task {
                let outcome = await sync.value
                if gate.claim() { continuation.resume(returning: outcome) }
            }
            Task {
                try? await Task.sleep(for: timeout)
                if gate.claim() {
                    sync.cancel()
                    continuation.resume(returning: .failure(.timedOut))
                }
            }
        }
    }

    #if DEBUG
    /// Demonstration only. This declaration is absent from Release builds.
    func unlockForPrototype() {
        isUnlocked = true
        isPrototypeUnlock = true
        state = .unavailable("Debug demonstration unlock — no purchase was made.")
    }
    #endif

    // MARK: - Entitlements

    @discardableResult
    private func refreshEntitlements() async -> Bool {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.productIdentifier,
               transaction.revocationDate == nil {
                entitled = true
            }
        }

        #if DEBUG
        isUnlocked = entitled || isPrototypeUnlock
        #else
        isUnlocked = entitled
        #endif
        return entitled
    }

    private func grantConsumable(_ transaction: Transaction) {
        guard transaction.productID == Self.singleExportIdentifier,
              transaction.revocationDate == nil,
              !grantedTransactionIDs.contains(transaction.id) else { return }
        grantedTransactionIDs.insert(transaction.id)
        exportCredits += 1
        persistCredits()
        persistGranted()
    }

    private func persistCredits() {
        UserDefaults.standard.set(exportCredits, forKey: Self.creditsKey)
    }

    private func persistGranted() {
        // Bounded so the stored list cannot grow without limit.
        let trimmed = grantedTransactionIDs.sorted().suffix(Self.grantedLimit)
        UserDefaults.standard.set(trimmed.map { NSNumber(value: $0) }, forKey: Self.grantedKey)
    }

    /// Recognize only Apple's cancellation values through documented wrappers.
    /// A network cancellation is not evidence the customer canceled a purchase.
    /// https://developer.apple.com/documentation/storekit/storekiterror/systemerror(_:)
    /// https://developer.apple.com/documentation/foundation/nsunderlyingerrorkey
    nonisolated static func isCancellation(_ error: Error) -> Bool {
        var current: Error = error
        // A bounded walk also handles a malformed/cyclic NSError chain safely.
        for _ in 0..<8 {
            if let storeError = current as? StoreKitError {
                switch storeError {
                case .userCancelled: return true
                case .systemError(let underlying):
                    current = underlying
                    continue
                default: return false
                }
            }
            let nsError = current as NSError
            if nsError.domain == SKErrorDomain {
                return nsError.code == SKError.Code.paymentCancelled.rawValue
            }
            guard let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error else { return false }
            current = underlying
        }
        return false
    }

    nonisolated private static func purchaseErrorDiagnostic(_ error: Error) -> String {
        var current: Error? = error
        var chain: [String] = []
        for _ in 0..<8 {
            guard let failure = current else { break }
            let nsError = failure as NSError
            let kind: String
            if let storeError = failure as? StoreKitError {
                switch storeError {
                case .userCancelled: kind = "StoreKitError.userCancelled"
                case .notAvailableInStorefront: kind = "StoreKitError.notAvailableInStorefront"
                case .notEntitled: kind = "StoreKitError.notEntitled"
                case .unknown: kind = "StoreKitError.unknown"
                case .unsupported: kind = "StoreKitError.unsupported"
                case .systemError: kind = "StoreKitError.systemError"
                case .networkError: kind = "StoreKitError.networkError"
                default: kind = "StoreKitError.other"
                }
            } else {
                kind = String(reflecting: type(of: failure))
            }
            chain.append("\(kind) domain=\(nsError.domain) code=\(nsError.code)")
            if let storeError = failure as? StoreKitError, case .systemError(let underlying) = storeError {
                current = underlying
            } else {
                current = nsError.userInfo[NSUnderlyingErrorKey] as? Error
            }
        }
        if current != nil { chain.append("Underlying chain truncated after eight errors") }
        return chain.joined(separator: "\n")
    }

    private static func message(for error: Error) -> String {
        if error is StoreKitError {
            return "The App Store could not complete that request. Check your connection and try again."
        }
        return "The App Store is unavailable right now. Try again shortly."
    }
}

enum AccountSyncOutcome: Error {
    case timedOut
    case thrown(Error)
}

/// Lets exactly one of two racing tasks resume a continuation. Without it the
/// late finisher would resume an already-resumed continuation and trap.
private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
