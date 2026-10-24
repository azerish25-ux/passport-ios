//
//  PassportProofApp.swift
//  PassportProof
//
//  Entry point. Injects the entitlement store and the in-memory photo session.
//  No analytics, no crash reporter, no network client: StoreKit is the only
//  network surface and it belongs to Apple (P5).
//

import SwiftUI

@main
struct PassportProofApp: App {

    @StateObject private var entitlements = EntitlementStore()
    @StateObject private var session = PhotoSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(entitlements)
                .environmentObject(session)
                .task {
                    await entitlements.refresh()
                }
        }
    }
}
