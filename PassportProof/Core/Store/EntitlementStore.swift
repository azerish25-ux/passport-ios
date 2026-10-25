//
//  EntitlementStore.swift
//  PassportProof
//
//  StoreKit 2, one non-consumable, no server. Entitlement is recomputed from
//  verified current transactions, including launch, restore and live updates.
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

@MainActor
final class EntitlementStore: ObservableObject {
    static let productIdentifier = "com.passportproof.app.unlock"
    static let fallbackPrice = "$17.99"

    @Published private(set) var isUnlocked = false
    @Published private(set) var displayPrice = EntitlementStore.fallbackPrice
    @Published private(set) var state: EntitlementState = .loading
    @Published private(set) var isWorking = false
    @Published private(set) var isPrototypeUnlock = false

    /// Session-only diagnostics for a failed attempt. Contains error types,
    /// domains and codes, never descriptions, account data or full userInfo.
    private(set) var lastPurchaseErrorDiagnostic: String?

    private var product: Product?
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }
                guard transaction.productID == EntitlementStore.productIdentifier else { continue }
                let entitled = await self.refreshEntitlements()
                if entitled { self.state = .purchased }
                else if self.product != nil { self.state = .available }
                else { self.state = .unavailable("The store is unavailable. Refresh to try again.") }
                await transaction.finish()
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
            let products = try await Product.products(for: [Self.productIdentifier])
            guard let product = products.first else {
                self.product = nil
                displayPrice = Self.fallbackPrice
                if !isUnlocked {
                    #if DEBUG
                    state = .unavailable("StoreKit has no product configured. A debug-only demonstration unlock is available.")
                    #else
                    state = .unavailable("The one-time unlock is not available yet. Check your connection and try again shortly.")
                    #endif
                }
                return
            }

            self.product = product
            displayPrice = product.displayPrice
            if !isUnlocked { state = .available }
        } catch {
            if isUnlocked {
                state = .purchased
            } else {
                state = .failed(Self.message(for: error))
            }
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard !isWorking else { return }
        guard let product else {
            state = .unavailable("The one-time unlock is not available yet. Try again shortly.")
            return
        }

        isWorking = true
        lastPurchaseErrorDiagnostic = nil
        defer { isWorking = false }

        do {
            let result = try await product.purchase()
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

    // MARK: - Restore

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        if await refreshEntitlements() {
            state = .purchased
            return
        }

        do {
            try await AppStore.sync()
        } catch {
            state = .failed(Self.message(for: error))
            return
        }

        if await refreshEntitlements() {
            state = .purchased
        } else {
            state = .failed("No previous PassportProof purchase was found for this Apple Account.")
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
            chain.append("\(String(reflecting: type(of: failure))) domain=\(nsError.domain) code=\(nsError.code)")
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
