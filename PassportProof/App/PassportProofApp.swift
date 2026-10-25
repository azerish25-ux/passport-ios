//
//  PassportProofApp.swift
//  PassportProof
//
//  Entry point. No analytics, account or application backend. An opaque privacy
//  cover prevents session photos appearing in the app switcher.
//

import SwiftUI

@main
@MainActor
struct PassportProofApp: App {
    @StateObject private var entitlements = EntitlementStore()
    @StateObject private var session = PhotoSession()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLargeTextUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestLargeText")
    }

    init() {
        // Remove leftovers from a prior process; current active shares are kept.
        _ = ExportStaging.cleanupAbandonedFiles()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                appRoot
                    .environmentObject(entitlements)
                    .environmentObject(session)
                    .task { await entitlements.refresh() }

                if scenePhase != .active {
                    PrivacyShield()
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: scenePhase)
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

private struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.m) {
                Image(systemName: "lock.shield.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.accent)
                Text("PassportProof")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text("Your photo is covered while the app is inactive.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
