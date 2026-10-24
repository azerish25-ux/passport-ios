//
//  EntitlementStore.swift
//  PassportProof
//
//  One non-consumable, no subscription, no server. Entitlement is whatever
//  StoreKit reports; there is no receipt check of our own to fall back on.
//
//  A prototype build with no App Store Connect record gets an empty product
//  list. In that case the store says so and offers an explicitly labelled
//  prototype unlock. It never reports `.purchased` for that path.
//

import Foundation
import Combine
import StoreKit

// MARK: - State

enum EntitlementState: Equatable, Sendable {
    case loading
    case available
    case purchased
    case unavailable(String)
    case failed(String)
}

// MARK: - Store

@MainActor
final class EntitlementStore: ObservableObject {

    static let productIdentifier = "com.passportproof.app.unlock"
    static let prototypePrice = "$17.99"

    @Published private(set) var isUnlocked: Bool
    @Published private(set) var displayPrice: String
    @Published private(set) var state: EntitlementState
    /// True only after `unlockForPrototype()`. The UI must label it as such.
    @Published private(set) var isPrototypeUnlock: Bool

    private var product: Product?

    init() {
        isUnlocked = false
        displayPrice = EntitlementStore.prototypePrice
        state = .loading
        isPrototypeUnlock = false
    }

    // MARK: - Loading

    func refresh() async {
        state = .loading
        do {
            let products = try await Product.products(for: [EntitlementStore.productIdentifier])
            guard let product = products.first else {
                self.product = nil
                displayPrice = EntitlementStore.prototypePrice
                state = .unavailable("No StoreKit product configured — prototype build")
                return
            }
            self.product = product
            displayPrice = product.displayPrice
            await refreshEntitlements()
            if !isUnlocked {
                state = .available
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = self.product else {
            state = .unavailable("No StoreKit product configured — prototype build")
            return
        }

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
                    // Do not grant on an unverified transaction.
                    state = .failed("The purchase could not be verified on this device.")
                }
            case .userCancelled:
                state = .available
            case .pending:
                state = .failed("The purchase is pending and has not completed.")
            @unknown default:
                state = .available
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            state = .failed(error.localizedDescription)
            return
        }
        await refreshEntitlements()
        if !isUnlocked {
            if product == nil {
                state = .unavailable("No StoreKit product configured — prototype build")
            } else {
                state = .available
            }
        }
    }

    // MARK: - Prototype bypass

    /// Clearly labelled bypass for builds with no StoreKit configuration.
    /// Sets `isPrototypeUnlock` so the UI can say "prototype unlock — no
    /// purchase was made" next to it. Never sets `.purchased`.
    func unlockForPrototype() {
        isUnlocked = true
        isPrototypeUnlock = true
        state = .unavailable("Prototype unlock — no purchase was made and no StoreKit product is configured.")
    }

    // MARK: - Private

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == EntitlementStore.productIdentifier,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        if entitled {
            isUnlocked = true
            isPrototypeUnlock = false
            state = .purchased
        }
    }
}
