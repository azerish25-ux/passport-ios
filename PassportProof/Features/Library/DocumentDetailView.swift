//
//  DocumentDetailView.swift
//  PassportProof
//
//  F6: every rule with its provenance, its source, and its date. Nothing on this
//  screen is decorative — each row is a claim and each claim carries where it
//  came from.
//

import SwiftUI

struct DocumentDetailView: View {
    let spec: DocumentSpec

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                identity
                Theme.SectionHeader(
                    title: "Rules encoded",
                    trailing: "verified \(Format.day(spec.verifiedOn))"
                )
                rulesSection
                Theme.SectionHeader(
                    title: "Changelog",
                    trailing: "\(spec.changelog.count)"
                )
                changelogSection
                Theme.SectionHeader(title: "Source")
                sourceSection
            }
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { measureBar }
    }

    // MARK: Identity

    private var identity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(spec.countryCode)
                .typeStyle(Typography.mrz)
                .foregroundStyle(Theme.inkSecondary)

            Text(spec.displayName)
                .typeStyle(Typography.title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(Format.sizeMM(width: spec.widthMM, height: spec.heightMM)) · \(Format.sizePixels(width: spec.widthPixels, height: spec.heightPixels)) · 300 dpi")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            if spec.isPrototypeData {
                Text("Prototype data. These figures have not been through the corpus verification process.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.signalVerify)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.l)
    }

    // MARK: Rules

    private var rules: [RuleLine] {
        var lines: [RuleLine] = []

        lines.append(
            RuleLine(
                id: "size",
                label: "Photo size",
                value: "\(Format.sizeMM(width: spec.widthMM, height: spec.heightMM)) · \(Format.sizePixels(width: spec.widthPixels, height: spec.heightPixels))",
                provenance: .source,
                date: spec.verifiedOn
            )
        )

        lines.append(
            RuleLine(
                id: "head-height",
                label: "Head height",
                value: Format.range(spec.headHeightMM.lowerBound, spec.headHeightMM.upperBound, unit: "mm"),
                provenance: .source,
                date: spec.verifiedOn
            )
        )

        if let share = spec.headHeightShare {
            lines.append(
                RuleLine(
                    id: "head-share",
                    label: "Head share of frame",
                    value: "\(percent(share.lowerBound))–\(percent(share.upperBound))% of image height",
                    provenance: .source,
                    date: spec.verifiedOn
                )
            )
        }

        if let eye = spec.eyeLineFromBottomMM {
            lines.append(
                RuleLine(
                    id: "eye-line",
                    label: "Eye line",
                    value: "\(Format.range(eye.lowerBound, eye.upperBound, unit: "mm")) from the bottom edge",
                    provenance: .source,
                    date: spec.verifiedOn
                )
            )
        }

        lines.append(
            RuleLine(
                id: "background",
                label: "Background",
                value: spec.backgroundDescription,
                provenance: .source,
                date: spec.verifiedOn
            )
        )

        lines.append(
            RuleLine(
                id: "headroom",
                label: "Headroom",
                value: Format.range(
                    spec.heightMM - spec.headHeightMM.upperBound,
                    spec.heightMM - spec.headHeightMM.lowerBound,
                    unit: "mm"
                ),
                provenance: .derived,
                date: spec.verifiedOn,
                footnote: "No published headroom rule exists. This is the frame height minus the head-height band, shown for reference only."
            )
        )

        return lines
    }

    private var rulesSection: some View {
        ForEach(rules) { line in
            RuleLineView(line: line, sourceHost: spec.sourceURL.host ?? "source")
            Theme.Rule()
        }
    }

    // MARK: Changelog

    private var changelogSection: some View {
        Group {
            if spec.changelog.isEmpty {
                Text("No changelog entries.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .padding(.horizontal, Theme.Spacing.margin)
                    .padding(.vertical, Theme.Spacing.m)
            } else {
                ForEach(spec.changelog) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                        Text(Format.day(entry.date))
                            .typeStyle(Typography.tabular)
                            .foregroundStyle(Theme.inkTertiary)
                            .lineLimit(1)

                        Text(entry.note)
                            .typeStyle(Typography.bodySmall)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Theme.Spacing.margin)
                    .padding(.vertical, Theme.Spacing.m)

                    Theme.Rule()
                }
            }
        }
    }

    // MARK: Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sourceLine(label: "Address", value: spec.sourceURL.absoluteString)
            sourceLine(label: "Host", value: spec.sourceURL.host ?? "—")
            sourceLine(label: "Verified", value: Format.day(spec.verifiedOn))

            Text("Every figure above is quoted from the issuer's own published guidance at the address shown. Where no tolerance is published, the diagnosis labels the value as a prototype default rather than presenting it as a rule.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.xxxl)
    }

    private func sourceLine(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Typography.unit.text(label)
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .typeStyle(Typography.tabular)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    // MARK: Primary action

    private var measureBar: some View {
        VStack(spacing: 0) {
            Theme.Rule()

            NavigationLink(value: AppRoute.capture(documentID: spec.id)) {
                Text("Measure a photo")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: true))
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.paper)
    }

    // MARK: Helpers

    /// The corpus may store a share as 0.50–0.69 or as 50–69. Both render as 50–69.
    private func percent(_ value: Double) -> String {
        let scaled = value <= 1.0 ? value * 100 : value
        return String(format: "%.0f", scaled)
    }
}

// MARK: - Rule line model

private struct RuleLine: Identifiable {
    let id: String
    let label: String
    let value: String
    let provenance: Provenance
    let date: Date
    var footnote: String? = nil
}

private struct RuleLineView: View {
    let line: RuleLine
    let sourceHost: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Typography.unit.text(line.label)
                    .foregroundStyle(Theme.inkTertiary)

                Text(line.value)
                    .typeStyle(Typography.measurementInline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)

                Text("\(line.provenance.uiLabel) · \(sourceHost) · verified \(Format.day(line.date))")
                    .typeStyle(Typography.tabular)
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                if let footnote = line.footnote {
                    Text(footnote)
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Spacing.xxs)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.vertical, Theme.Spacing.m)
    }
}
