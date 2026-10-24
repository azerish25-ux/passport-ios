//
//  DocumentLibraryView.swift
//  PassportProof
//
//  Cold-launch screen. The corpus is the product, so the first thing on screen
//  is what is encoded and — in the same breath — what is not.
//
//  The counter is `documents.count` of `launchTargetCount`, never a hard-coded
//  "4 of 12": if the corpus grows, the header grows with it.
//

import SwiftUI

struct DocumentLibraryView: View {

    private var encoded: [DocumentSpec] { DocumentCorpus.documents }
    private var pending: [String] { DocumentCorpus.pendingDocumentNames }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ScreenTitle(
                    title: "PassportProof",
                    subtitle: "Photo measurement against the published rules for one document. Informational diagnosis only."
                )

                Theme.SectionHeader(
                    title: "\(encoded.count) of \(DocumentCorpus.launchTargetCount) documents encoded"
                )

                ForEach(encoded) { spec in
                    NavigationLink(value: AppRoute.documentDetail(documentID: spec.id)) {
                        DocumentRow(spec: spec)
                    }
                    .buttonStyle(.plain)

                    Theme.Rule()
                }

                coverageNote

                if !pending.isEmpty {
                    Theme.SectionHeader(
                        title: "Not encoded",
                        trailing: "\(pending.count)"
                    )

                    ForEach(pending, id: \.self) { name in
                        PendingRow(name: name)
                        Theme.Rule()
                    }
                }

                footer
            }
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Header note

    private var coverageNote: some View {
        Text("\(pending.count) of the \(DocumentCorpus.launchTargetCount) launch documents are not encoded yet. Nothing is inferred for a document that is not listed — where one is missing, the counter at the intake desk remains the reference.")
            .typeStyle(Typography.meta)
            .foregroundStyle(Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Theme.Rule(color: Theme.ruleStrong, weight: Theme.Stroke.rule)

            Text("Photographs are measured on this device and are never uploaded or stored. There is no account.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xxl)
        .padding(.bottom, Theme.Spacing.xxxl)
    }
}

// MARK: - Document row

/// Height 72 minimum, full-bleed, hairline between rows, no card, no shadow.
/// The code column never wraps and never truncates.
private struct DocumentRow: View {
    let spec: DocumentSpec

    private var geometryLine: String {
        "\(Format.sizeMM(width: spec.widthMM, height: spec.heightMM)) · \(Format.sizePixels(width: spec.widthPixels, height: spec.heightPixels))"
    }

    private var headLine: String {
        Format.range(
            spec.headHeightMM.lowerBound,
            spec.headHeightMM.upperBound,
            unit: "mm"
        )
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {

            Text(spec.countryCode)
                .typeStyle(Typography.mrz)
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: Theme.Metrics.documentCodeColumn, alignment: .leading)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {

                Text(spec.documentName)
                    .typeStyle(Typography.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(spec.country) · \(geometryLine)")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Typography.unit.text("head")
                        .foregroundStyle(Theme.inkTertiary)

                    Text(headLine)
                        .typeStyle(Typography.tabular)
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: Theme.Spacing.s)

                    Text("verified \(Format.day(spec.verifiedOn))")
                        .typeStyle(Typography.tabular)
                        .foregroundStyle(Theme.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.top, Theme.Spacing.xs)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.vertical, Theme.Spacing.m)
        .frame(minHeight: Theme.Metrics.documentRowHeight, alignment: .top)
        .contentShape(Rectangle())
    }
}

// MARK: - Pending row

/// A document that is counted but not encoded. Deliberately quieter than an
/// encoded row and carrying no geometry, because there is none to state.
private struct PendingRow: View {
    let name: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            Text("—")
                .typeStyle(Typography.tabular)
                .foregroundStyle(Theme.inkTertiary)
                .frame(width: Theme.Metrics.documentCodeColumn, alignment: .leading)

            Text(name)
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.vertical, Theme.Spacing.m)
        .frame(minHeight: Theme.Metrics.tapTarget, alignment: .center)
    }
}
