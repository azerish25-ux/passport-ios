//
//  PrivacyView.swift
//  PassportProof
//
//  In-app, human-readable privacy disclosure matching the bundled manifest.
//

import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    HStack(alignment: .center, spacing: Theme.Spacing.m) {
                        StudioMark()
                        StudioEyebrow(title: "Your photo, your device")
                    }
                    Text("Private by design")
                        .font(.system(.largeTitle, design: .serif))
                        .tracking(-0.7)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("A document photo is personal. We built PassportProof to keep it that way.")
                        .font(.body)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Label("Photo analysis stays on your device", systemImage: "iphone")
                        Label("No account or tracking", systemImage: "person.crop.circle.badge.checkmark")
                        Label("You decide when to share", systemImage: "square.and.arrow.up")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .padding(Theme.Spacing.l)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }

                PrivacySection(
                    title: "Photos",
                    icon: "photo",
                    rows: [
                        "Photo checks run on your device. We never upload your photograph for analysis.",
                        "Your selected photo and crop are kept only for the current session. The app does not add them to your photo library or keep a photo archive.",
                        "A temporary export file is removed after sharing finishes or you leave the export screen. Copies you choose to save or send remain wherever you put them."
                    ]
                )

                PrivacySection(
                    title: "Permissions",
                    icon: "camera",
                    rows: [
                        "Camera access is requested only when you choose live capture. You can use the library instead.",
                        "Photo access is handled by the system photo picker; PassportProof receives only the image you select.",
                        "Permission choices can be changed at any time in iOS Settings."
                    ]
                )

                PrivacySection(
                    title: "Data collection",
                    icon: "chart.bar.xaxis",
                    rows: [
                        "No account, advertising identifier, analytics SDK, crash-reporting service, remote configuration or tracking.",
                        "No photo metadata is transmitted. Capture date and visual confirmations remain session-only inputs to the checks.",
                        "We do not build a profile of you or monitor how you use the app."
                    ]
                )

                PrivacySection(
                    title: "Purchases and external links",
                    icon: "creditcard",
                    rows: [
                        "The optional export unlock is processed by Apple through StoreKit. PassportProof does not receive your payment details.",
                        "StoreKit may use Apple's network services to retrieve products, purchases and entitlements.",
                        "Issuer guidance links open in your browser only when you tap them. No photo or session data is attached to those links."
                    ]
                )

                Text("Informational diagnosis only. The issuing authority makes the final decision about any photograph or document.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.margin)
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background(Theme.paper)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: Theme.Metrics.tapTarget)
            }
        }
    }
}

private struct PrivacySection: View {
    let title: String
    let icon: String
    let rows: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Label(title, systemImage: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Circle()
                        .fill(Theme.sageStrong)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                        .accessibilityHidden(true)
                    Text(row)
                        .typeStyle(Typography.bodySmall)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.rule, lineWidth: 0.7))
    }
}
