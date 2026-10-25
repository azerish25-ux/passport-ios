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
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    Image(systemName: "lock.shield.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Theme.accent)
                    Text("Private by design")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("PassportProof is built so your photograph and personal activity do not become a data product.")
                        .font(.body)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PrivacySection(
                    title: "Photos",
                    icon: "photo",
                    rows: [
                        "Analysis runs on your device. No photograph is uploaded to PassportProof or a third-party analytics service.",
                        "Your selected crop is held in memory for the current session. It is not saved to Photos, a database or an app cache.",
                        "An exported file is written to temporary protected storage only for the system share sheet and is deleted when sharing finishes or the export screen closes."
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
                        "The bundled privacy manifest declares no collected data and no tracking."
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
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: Theme.Spacing.s) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 3)
                    Text(row)
                        .typeStyle(Typography.bodySmall)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 18))
    }
}
