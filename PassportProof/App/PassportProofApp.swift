//
//  PassportProofApp.swift
//  PassportProof
//
//  Entry point. No analytics, account or application backend. A scene-level
//  privacy cover obscures the interface when the app moves to the background.
//

import SwiftUI

@main
@MainActor
struct PassportProofApp: App {
    @StateObject private var entitlements = EntitlementStore()
    @StateObject private var session = PhotoSession()

    private var isLargeTextUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestLargeText")
    }

    init() {
        // Remove leftovers from a prior process; current active shares are kept.
        _ = ExportStaging.cleanupAbandonedFiles()
        PrivacyShieldCoordinator.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            appRoot
                .environmentObject(entitlements)
                .environmentObject(session)
                .task { await entitlements.refresh() }
        }
    }

    @ViewBuilder
    private var appRoot: some View {
        if isLargeTextUITest {
            RootView().dynamicTypeSize(.accessibility3)
        } else {
            RootView()
                .preferredColorScheme(isDarkUITest ? .dark : nil)
        }
    }

    private var isDarkUITest: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-UITestDarkMode")
        #else
        return false
        #endif
    }
}
