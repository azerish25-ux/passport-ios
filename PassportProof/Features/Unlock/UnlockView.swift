//
//  UnlockView.swift
//  PassportProof
//
//  One price, one button, one sentence about what it buys. No subscription, no
//  trial, no credit pack (P3).
//
//  When StoreKit has no product — the normal case for a prototype with no App
//  Store Connect record — the screen says so, verbatim, and offers a bypass that
//  is labelled as a bypass. Nothing on this screen claims a purchase succeeded.
//

import SwiftUI

@MainActor
struct UnlockView: View {

    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss

    @State private var isWorking = false

    private var price: String {
        entitlements.displayPrice.isEmpty ? "—" : entitlements.displayPrice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ScreenTitle(title: "Unlock")

                priceBlock
                sentence
                action
                footnote

                Spacer(minLength: Theme.Spacing.xxxl)
            }
        }
        .background(Theme.paper)
        .navigationTitle("Unlock")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await entitlements.refresh()
        }
        .onChange(of: entitlements.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    // MARK: Price

    private var priceBlock: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Typography.measurement.text(price)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Typography.unit.text("once")
                .foregroundStyle(Theme.inkTertiary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xxl)
    }

    private var sentence: some View {
        Text("One purchase, held by the App Store. It unlocks the print sheet and the digital file for every encoded document, on this device. It does not buy a review, a decision, or a better outcome.")
            .typeStyle(Typography.bodySmall)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)
    }

    // MARK: State

    @ViewBuilder
    private var action: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if entitlements.isUnlocked || entitlements.state == .purchased {
                unlockedBlock
            } else {
                storeState
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xxl)
    }

    /// Kept in its own `@ViewBuilder` so the switch is type-checked separately
    /// from the surrounding layout.
    @ViewBuilder
    private var storeState: some View {
        switch entitlements.state {

        case .loading:
            Typography.findingLabel.text("Checking the store")
                .foregroundStyle(Theme.inkTertiary)

        case .available:
            PrimaryButton(title: "Unlock for \(price)", isEnabled: !isWorking) {
                purchase()
            }

            SecondaryAction(title: "Restore purchase") {
                restore()
            }

        case .purchased:
            unlockedBlock

        case .unavailable(let reason):
            notice(reason)
            prototypeBlock

        case .failed(let reason):
            notice(reason)

            PrimaryButton(title: "Try again", isEnabled: !isWorking) {
                purchase()
            }

            SecondaryAction(title: "Restore purchase") {
                restore()
            }
        }
    }

    private var unlockedBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Typography.findingLabel.text(entitlements.isPrototypeUnlock ? "Prototype unlock" : "Unlocked")
                .foregroundStyle(Theme.signalPass)

            Text(entitlements.isPrototypeUnlock
                 ? "The print sheet and the digital file are available. No purchase was made and nothing was charged."
                 : "The print sheet and the digital file are available.")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Theme.Stroke.statusRail + Theme.Spacing.m)
        .padding(.trailing, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.paper)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.signalPass)
                .frame(width: Theme.Stroke.statusRail)
        }
    }

    /// The store's own words, unedited. If it says there is no product, that is
    /// what the screen says.
    private func notice(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Typography.findingLabel.text("Store unavailable")
                .foregroundStyle(Theme.signalVerify)

            Text(reason)
                .typeStyle(Typography.tabular)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("No purchase can complete in this build. Nothing is charged, and no receipt is created.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Theme.Stroke.statusRail + Theme.Spacing.m)
        .padding(.trailing, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.verifyWash)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.signalVerify)
                .frame(width: Theme.Stroke.statusRail)
        }
    }

    private var prototypeBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PrimaryButton(title: "Unlock for prototype", isEnabled: !isWorking) {
                unlockForPrototype()
            }

            Text("A prototype bypass, not a purchase. It exists so the export screens can be demonstrated without an App Store record, and it is labelled so it cannot be read as a transaction.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footnote: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Theme.Rule(color: Theme.ruleStrong, weight: Theme.Stroke.rule)

            Text("No account, no subscription, no server. The entitlement is whatever the App Store reports for this device.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xxl)
    }

    // MARK: Work

    private func purchase() {
        isWorking = true
        Task {
            await entitlements.purchase()
            await MainActor.run { isWorking = false }
        }
    }

    private func restore() {
        isWorking = true
        Task {
            await entitlements.restore()
            await MainActor.run { isWorking = false }
        }
    }

    private func unlockForPrototype() {
        // Synchronous by design: the bypass touches no StoreKit state and does
        // no I/O, so there is nothing to await.
        entitlements.unlockForPrototype()
    }
}
