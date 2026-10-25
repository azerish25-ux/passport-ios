//
//  DocumentDetailView.swift
//  PassportProof
//
//  Requirements, provenance and output constraints for one complete workflow.
//

import SwiftUI

struct DocumentDetailView: View {
    let spec: DocumentSpec

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                identity
                quickFacts
                guidance
                rulesSection
                sourceSection
                changelogSection
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { measureBar }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text(spec.countryCode)
                    .font(.system(.headline, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.onInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 10))
                Text(spec.workflow.shortTitle)
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Theme.accent.opacity(0.1), in: Capsule())
                Spacer()
            }

            Text(spec.displayName)
                .font(.largeTitle.weight(.bold))
                .tracking(-0.7)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(spec.supportsPrintSheet
                 ? "A calibrated print workflow for a 2 × 2 inch photo."
                 : "A portal-ready JPEG workflow with geometry and file-size checks.")
                .font(.body)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
    }

    private var quickFacts: some View {
        VStack(spacing: 0) {
            FactRow(
                title: spec.supportsPrintSheet ? "Printed size" : "Digital geometry",
                value: spec.supportsPrintSheet
                    ? Format.sizeMM(width: spec.widthMM, height: spec.heightMM)
                    : Format.sizePixels(width: spec.widthPixels, height: spec.heightPixels)
            )
            Theme.Rule()
            FactRow(
                title: "Head height",
                value: Format.range(spec.headHeightMM.lowerBound, spec.headHeightMM.upperBound, unit: "mm")
            )
            Theme.Rule()
            FactRow(title: "Photo age", value: "Within \(Format.compact(spec.maximumPhotoAgeMonths)) months")
            if let maximum = spec.maximumFileSizeBytes {
                Theme.Rule()
                FactRow(title: "Maximum file size", value: "\(maximum / 1_000) kB")
            }
        }
        .background(Theme.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.rule, lineWidth: 0.5)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Before you capture")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            GuidanceRow(icon: "square.on.square", title: "Background", detail: spec.backgroundDescription)
            GuidanceRow(icon: "face.smiling", title: "Expression", detail: spec.expressionRequirement)
            GuidanceRow(icon: "eyeglasses", title: "Glasses", detail: spec.glassesRequirement)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Theme.SectionHeader(title: "Rules encoded", trailing: "verified \(Format.day(spec.verifiedOn))")
            VStack(spacing: Theme.Spacing.s) {
                if let share = spec.headHeightShare {
                    RulePill(
                        title: "Head share of frame",
                        value: "\(Int((share.lowerBound * 100).rounded()))–\(Int((share.upperBound * 100).rounded()))% of image height"
                    )
                }
                if let eye = spec.eyeLineFromBottomMM {
                    RulePill(
                        title: "Eye line",
                        value: "\(Format.range(eye.lowerBound, eye.upperBound, unit: "mm")) from the bottom edge"
                    )
                }
                RulePill(title: "Output", value: spec.supportsPrintSheet ? "300 DPI physical print sheet" : "JPEG · sRGB · exact portal geometry")
                RulePill(title: "Original photo", value: "No filters, retouching or background replacement; reviewed geometric crop only")
            }
        }
        .padding(.top, Theme.Spacing.m)
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Theme.SectionHeader(title: "Source & verification")
            Text("Rules are taken from the issuer's published guidance and dated when checked. App-selected measurement thresholds are labelled separately in findings.")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: spec.sourceURL) {
                Label("Open issuer guidance", systemImage: "safari")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityHint("Opens in your browser. No photo or session data is shared.")
            Text(spec.sourceURL.host ?? "Issuer website")
                .font(.caption)
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private var changelogSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Theme.SectionHeader(title: "Changelog")
            ForEach(spec.changelog) { entry in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(Format.day(entry.date))
                        .typeStyle(Typography.tabular)
                        .foregroundStyle(Theme.inkSecondary)
                    Text(entry.note)
                        .typeStyle(Typography.bodySmall)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, Theme.Spacing.margin)
            }
        }
        .padding(.top, Theme.Spacing.m)
    }

    private var measureBar: some View {
        VStack(spacing: 0) {
            NavigationLink(value: AppRoute.capture(documentID: spec.id)) {
                Text("Measure a photo")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: true))
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.paperRaised)
        .overlay(alignment: .top) { Theme.Rule() }
    }
}

private struct FactRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.l)
    }
}

private struct GuidanceRow: View {
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
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct RulePill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(Theme.inkSecondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, Theme.Spacing.margin)
    }
}
