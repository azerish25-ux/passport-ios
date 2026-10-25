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

    private var product: Product?
    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                guard case .verified(let transaction) = result else { continue }
                guard transaction.productID == EntitlementStore.productIdentifier else { continue }
                let entitled = await self.refreshEntitlements()
                self.state = entitled ? .purchased : .available
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

        do {
            let products = try await Product.products(for: [Self.productIdentifier])
            guard let product = products.first else {
                self.product = nil
                displayPrice = Self.fallbackPrice
                _ = await refreshEntitlements()
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
            let entitled = await refreshEntitlements()
            state = entitled ? .purchased : .available
        } catch {
            state = .failed(Self.message(for: error))
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
            state = .failed(Self.message(for: error))
        }
    }

    // MARK: - Restore

    func restore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await AppStore.sync()
        } catch {
            state = .failed(Self.message(for: error))
            return
        }

        let entitled = await refreshEntitlements()
        if entitled {
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

    private static func message(for error: Error) -> String {
        if error is StoreKitError {
            return "The App Store could not complete that request. Check your connection and try again."
        }
        return "The App Store is unavailable right now. Try again shortly."
    }
}
