//
//  UnlockView.swift
//  PassportProof
//
//  One non-consumable purchase with restore, pending and failure recovery.
//  The demonstration path is compiled only for DEBUG.
//

import SwiftUI

@MainActor
struct UnlockView: View {
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss

    private var price: String {
        entitlements.state == .loading ? "—" : entitlements.displayPrice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                hero
                benefits
                purchaseArea
                reassurance
            }
            .padding(Theme.Spacing.margin)
        }
        .background(Theme.paper)
        .navigationTitle("Export unlock")
        .navigationBarTitleDisplayMode(.inline)
        .task { await entitlements.refresh() }
        .onChange(of: entitlements.isUnlocked) { _, unlocked in
            if unlocked && !entitlements.isPrototypeUnlock { dismiss() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
                .frame(width: 64, height: 64)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
            Text("One unlock.\nEvery export.")
                .font(.largeTitle.weight(.bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.ink)
            Text("Precise print sheets or portal-ready digital files, created from the photo you reviewed.")
                .font(.body)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text(price)
                    .font(.system(.largeTitle, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("one time")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            BenefitRow(icon: "printer.fill", title: "Precision print sheets", detail: "Physical page geometry and a free calibration sheet.")
            BenefitRow(icon: "square.and.arrow.up.fill", title: "Portal-ready digital files", detail: "Exact pixels, sRGB JPEG and verified file-size limits.")
            BenefitRow(icon: "infinity", title: "No subscription", detail: "One purchase linked to your Apple Account, with restore support.")
            BenefitRow(icon: "lock.shield.fill", title: "Private by design", detail: "No account, analytics or photo upload.")
        }
        .padding(Theme.Spacing.l)
        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder
    private var purchaseArea: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if entitlements.isUnlocked || entitlements.state == .purchased {
                unlockedBlock
            } else {
                switch entitlements.state {
                case .loading:
                    HStack(spacing: Theme.Spacing.m) {
                        ProgressView()
                        Text("Connecting to the App Store…")
                            .foregroundStyle(Theme.inkSecondary)
                    }
                case .available:
                    purchaseButtons
                case .purchased:
                    unlockedBlock
                case .pending:
                    NoticeCard(
                        icon: "hourglass",
                        title: "Purchase pending",
                        message: "The purchase needs approval or more time. Restore after it completes; nothing is unlocked yet.",
                        tint: Theme.signalVerify
                    )
                    SecondaryAction(title: "Check purchase status", isEnabled: !entitlements.isWorking) {
                        Task { await entitlements.restore() }
                    }
                case .unavailable(let reason):
                    NoticeCard(
                        icon: "wifi.exclamationmark",
                        title: "Store unavailable",
                        message: reason,
                        tint: Theme.signalVerify
                    )
                    SecondaryAction(title: "Try again", isEnabled: !entitlements.isWorking) {
                        Task { await entitlements.refresh() }
                    }
                    #if DEBUG
                    prototypeBlock
                    #endif
                case .failed(let reason):
                    NoticeCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Could not complete the request",
                        message: reason,
                        tint: Theme.signalFail
                    )
                    PrimaryButton(title: "Try again", isEnabled: !entitlements.isWorking) {
                        Task { await entitlements.refresh() }
                    }
                    SecondaryAction(title: "Restore purchase", isEnabled: !entitlements.isWorking) {
                        Task { await entitlements.restore() }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("unlock.purchaseArea")
    }

    private var purchaseButtons: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            PrimaryButton(
                title: entitlements.isWorking ? "Contacting App Store…" : "Unlock for \(price)",
                isEnabled: !entitlements.isWorking
            ) {
                Task { await entitlements.purchase() }
            }
            .accessibilityIdentifier("unlock.purchase")
            SecondaryAction(title: "Restore purchase", isEnabled: !entitlements.isWorking) {
                Task { await entitlements.restore() }
            }
            .accessibilityIdentifier("unlock.restore")
        }
    }

    private var unlockedBlock: some View {
        Label(
            entitlements.isPrototypeUnlock
                ? "Debug demonstration unlock is active. No purchase was made."
                : "Export is unlocked for this Apple Account.",
            systemImage: "checkmark.circle.fill"
        )
        .font(.body.weight(.semibold))
        .foregroundStyle(Theme.signalPass)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.signalPass.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
    }

    #if DEBUG
    private var prototypeBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            SecondaryAction(title: "Continue with debug unlock", isEnabled: !entitlements.isWorking) {
                entitlements.unlockForPrototype()
            }
            Text("DEBUG only · not a purchase · omitted from Release builds")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(Theme.Spacing.m)
        .background(Theme.signalVerify.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
    #endif

    private var reassurance: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Purchase unlocks file export only. It does not change findings, buy a review or promise a different outcome.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Calibration, document guidance and on-device analysis remain available without purchase.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct NoticeCard: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(message)
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}
