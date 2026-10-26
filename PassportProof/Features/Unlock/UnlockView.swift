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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var price: String {
        entitlements.state == .loading ? "—" : entitlements.displayPrice
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                hero
                StudioCard { purchaseArea }
                benefits
                reassurance
            }
            .padding(Theme.Spacing.margin)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.paper)
        .navigationTitle("Export access")
        .navigationBarTitleDisplayMode(.inline)
        .task { await entitlements.refresh() }
        .onChange(of: entitlements.isUnlocked) { _, unlocked in
            if unlocked && !entitlements.isPrototypeUnlock { dismiss() }
        }
        .onChange(of: entitlements.exportCredits) { _, credits in
            // A verified single-export purchase returns the customer straight
            // to the export they were already preparing.
            if credits > 0 { dismiss() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            StudioEyebrow(title: "Pay once · no subscription")
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                Text("Your photo.\nYour finished file.")
                    .font(.system(.largeTitle, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    StudioPortraitArt(style: .printSheet)
                        .frame(width: 112, height: 140)
                }
            }
            Text("Export the exact crop you reviewed as a print sheet or a digital photo. Yours to save and share.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Theme.Spacing.s) {
                TrustChip(icon: "lock.shield", text: "On-device")
                TrustChip(icon: "arrow.clockwise", text: "Unlimited retries")
                TrustChip(icon: "creditcard", text: "Apple Pay")
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Everything before export stays free")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Document guidance, capture, crop, photo checks and the printer calibration page.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.l)
            .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: Theme.Radius.card))

            Text("Included in your unlock")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, Theme.Spacing.xs)
            BenefitRow(icon: "printer", title: "Print sheets, made to measure", detail: "PDF layouts for the supported US passport workflow. Choose your paper size and print at actual size.")
            BenefitRow(icon: "arrow.up.doc", title: "Digital files with the right format", detail: "600 × 600 pixel JPEGs with file-size checks for US visa and DV Lottery photos.")
            BenefitRow(icon: "infinity", title: "Unlimited supported exports", detail: "One purchase for your Apple Account. Restore it on another device using the same account.")
            BenefitRow(icon: "lock", title: "Processing stays on your device", detail: "No photo upload, account or tracking. Apple handles the purchase.")
        }
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
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("UNLIMITED EXPORTS")
                            .font(.caption2.weight(.semibold))
                            .tracking(1.2)
                            .foregroundStyle(Theme.accent)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(price)
                                .font(.system(.largeTitle, design: .monospaced, weight: .medium))
                                .tracking(-0.7)
                                .foregroundStyle(Theme.ink)
                                .accessibilityIdentifier("unlock.price")
                            Text("once")
                                .font(.subheadline)
                                .foregroundStyle(Theme.inkSecondary)
                        }
                        Text("Every document, every redo, on every device signed in to your Apple Account.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        purchaseButtons.padding(.top, Theme.Spacing.s)
                        if entitlements.exportCredits > 0 {
                            CreditNotice(credits: entitlements.exportCredits)
                        }
                    }
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
                title: entitlements.isWorking ? "Contacting App Store…" : "Unlock everything for \(price)",
                isEnabled: !entitlements.isWorking
            ) {
                Task { await entitlements.purchase() }
            }
            .accessibilityIdentifier("unlock.purchase")

            if entitlements.canBuySingleExport, let single = entitlements.singleExportPrice {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    PrimaryButton(
                        title: entitlements.purchasingProduct == .singleExport ? "Contacting App Store…" : "One export for \(single)",
                        emphasis: .outline,
                        isEnabled: !entitlements.isWorking
                    ) {
                        Task { await entitlements.purchaseSingleExport() }
                    }
                    .accessibilityIdentifier("unlock.purchaseSingle")
                    Text("One export credit for this device. It cannot be restored, and it does not expire.")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SecondaryAction(title: "Restore purchase", isEnabled: !entitlements.isWorking) {
                Task { await entitlements.restore() }
            }
            .accessibilityIdentifier("unlock.restore")
        }
    }

    private var unlockedBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(
                unlockConfirmation,
                systemImage: "checkmark.circle.fill"
            )
            .font(.body.weight(.semibold))
            .foregroundStyle(Theme.signalPass)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.signalPass.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

            if !entitlements.isPrototypeUnlock {
                SecondaryAction(title: "Restore purchases", isEnabled: !entitlements.isWorking) {
                    Task { await entitlements.restore() }
                }
                .accessibilityIdentifier("unlock.restore")
            }
        }
    }

    private var unlockConfirmation: String {
        #if DEBUG
        if entitlements.isPrototypeUnlock {
            return "Debug demonstration unlock is active. No purchase was made."
        }
        #endif
        return "Export is unlocked for this Apple Account."
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
            Text("Your results stay honest. A purchase unlocks export; it does not change photo findings or guarantee acceptance.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("PassportProof is independent of the issuing authority. The authority makes the final decision about your photo.")
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
                .frame(width: 36, height: 36)
                .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: 10))
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

private struct TrustChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2.weight(.semibold))
            Text(text).font(.caption2.weight(.medium))
        }
        .foregroundStyle(Theme.inkSecondary)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Theme.paperRaised, in: Capsule())
        .overlay(Capsule().stroke(Theme.rule, lineWidth: Theme.Stroke.hairline))
        .accessibilityElement(children: .combine)
    }
}

private struct CreditNotice: View {
    let credits: Int

    var body: some View {
        Label(
            credits == 1
                ? "You have 1 export credit ready to use."
                : "You have \(credits) export credits ready to use.",
            systemImage: "checkmark.seal"
        )
        .font(.footnote.weight(.medium))
        .foregroundStyle(Theme.signalPass)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Theme.Spacing.xs)
        .accessibilityIdentifier("unlock.credits")
    }
}
