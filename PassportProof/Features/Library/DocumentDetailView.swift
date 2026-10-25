//
//  DocumentDetailView.swift
//  PassportProof
//
//  A document brief: output first, practical preparation second, full sources
//  available without making the first-use workflow read like a specification.
//

import SwiftUI

struct DocumentDetailView: View {
    let spec: DocumentSpec
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showRules = false
    @State private var showHistory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                identity
                outputCard
                guidance
                facts
                sourceSection
            }
            .padding(Theme.Spacing.margin)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            StudioEyebrow(title: "United States · \(spec.workflow.shortTitle)")
            Text(spec.documentName)
                .font(.system(.largeTitle, design: .serif))
                .tracking(-0.7)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(spec.supportsPrintSheet
                 ? "For applications made in person or by mail."
                 : (spec.id == "us-visa" ? "Prepare a digital photo for a US visa application." : "Prepare a digital photo for a Diversity Visa entry."))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var outputCard: some View {
        StudioCard(padding: 16) {
            HStack(alignment: .center, spacing: Theme.Spacing.l) {
                if !dynamicTypeSize.isAccessibilitySize {
                    StudioPortraitArt(style: spec.supportsPrintSheet ? .printSheet : .digital)
                        .frame(width: 112, height: 138)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    StudioEyebrow(title: "Your finished format")
                    Text(spec.supportsPrintSheet ? "2 × 2 in" : "600 × 600")
                        .font(.system(.title, design: .monospaced, weight: .medium))
                        .tracking(-0.7)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(spec.supportsPrintSheet ? "Print-ready PDF sheet" : "Pixels · sRGB JPEG")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(spec.supportsPrintSheet ? "300 DPI · choose your paper size" : "File size checked before sharing")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var guidance: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Set up a good photo")
                .font(.title3.weight(.semibold))
                .tracking(-0.3)
                .foregroundStyle(Theme.ink)
            GuidanceRow(number: "01", title: "Find a plain background", detail: spec.backgroundDescription)
            GuidanceRow(number: "02", title: "Face the camera", detail: spec.expressionRequirement)
            GuidanceRow(number: "03", title: "Keep your eyes visible", detail: spec.glassesRequirement)
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(Theme.accent)
                Text("Use an original photo. Retake it if the lighting or background needs fixing; avoid filters and retouching.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var facts: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                StudioEyebrow(title: "The essentials")
                FactRow(title: "Head height", value: Format.range(spec.headHeightMM.lowerBound, spec.headHeightMM.upperBound, unit: "mm"))
                Theme.Rule()
                FactRow(title: "Photo taken", value: "Within \(Format.compact(spec.maximumPhotoAgeMonths)) months")
                if let maximum = spec.maximumFileSizeBytes {
                    Theme.Rule()
                    FactRow(title: "File limit", value: "\(maximum / 1_000) kB")
                }
                Theme.Rule()
                DisclosureGroup(isExpanded: $showRules) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                        if let share = spec.headHeightShare {
                            RuleDetail(title: "Head share of frame", value: "\(Int((share.lowerBound * 100).rounded()))–\(Int((share.upperBound * 100).rounded()))% of image height")
                        }
                        if let eye = spec.eyeLineFromBottomMM {
                            RuleDetail(title: "Eye line", value: "\(Format.range(eye.lowerBound, eye.upperBound, unit: "mm")) from the bottom edge")
                        }
                        RuleDetail(title: "Photo dimensions", value: Format.sizePixels(width: spec.widthPixels, height: spec.heightPixels))
                        RuleDetail(title: "Original photo", value: "No filters, retouching or background replacement. Only the geometric crop is adjusted.")
                    }
                    .padding(.top, Theme.Spacing.m)
                } label: {
                    Text("All photo requirements")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .padding(.vertical, 10)
                }
                .tint(Theme.accent)
                .accessibilityIdentifier("detail.requirements")
            }
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Based on issuer guidance")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Requirements checked \(Format.day(spec.verifiedOn)). App-selected measurement thresholds are identified separately in your results.")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Link(destination: spec.sourceURL) {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Read the official requirements")
                        .font(.subheadline.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "arrow.up.right").font(.caption.weight(.semibold))
                }
                .foregroundStyle(Theme.accent)
                .frame(minHeight: 44)
            }
            .accessibilityHint("Opens \(spec.sourceURL.host ?? "the issuer website") in your browser. No photo or session data is shared.")

            DisclosureGroup(isExpanded: $showHistory) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(spec.changelog) { entry in
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(Format.day(entry.date))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                            Text(entry.note)
                                .font(.caption)
                                .foregroundStyle(Theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, Theme.Spacing.s)
            } label: {
                Text("Requirement update history")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(minHeight: 44)
            }
            .tint(Theme.inkSecondary)
        }
    }

    private var actionBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            NavigationLink(value: AppRoute.capture(documentID: spec.id)) {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Take or choose a photo")
                    Image(systemName: "arrow.right").font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("detail.measure")
            Text("Photo checks are free · export is a one-time purchase")
                .font(.caption2)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.paperRaised)
        .overlay(alignment: .top) { Theme.Rule() }
    }
}

private struct FactRow: View {
    let title: String
    let value: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) { titleText; valueText }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    titleText
                    Spacer(minLength: 4)
                    valueText.multilineTextAlignment(.trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var titleText: some View {
        Text(title).font(.subheadline).foregroundStyle(Theme.inkSecondary)
    }
    private var valueText: some View {
        Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GuidanceRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Text(number)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 30, height: 30)
                .background(Theme.sageWash, in: Circle())
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RuleDetail: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
            Text(value).font(.caption).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
