//
//  DocumentLibraryView.swift
//  PassportProof
//
//  A focused catalogue with clear output choices and a useful first action.
//

import SwiftUI

struct DocumentLibraryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                introduction
                catalogue
                process
                privacyCard
                footer
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.paper)
        .safeAreaInset(edge: .top, spacing: 0) { brandHeader }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPrivacy) {
            NavigationStack { PrivacyView() }
                .dynamicTypeSize(dynamicTypeSize)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: Theme.Spacing.m) {
            StudioMark()
            VStack(alignment: .leading, spacing: 2) {
                Text("PassportProof")
                    .font(.headline.weight(.semibold))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("THE PRIVATE PHOTO STUDIO")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.3)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer(minLength: 4)
            Button { showPrivacy = true } label: {
                Image(systemName: "lock")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
                    .background(Theme.paperRaised, in: Circle())
                    .overlay(Circle().stroke(Theme.rule, lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Privacy and data use")
            .accessibilityIdentifier("library.privacy")
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.vertical, Theme.Spacing.m)
        .background(Theme.paper)
        .overlay(alignment: .bottom) { Theme.Rule() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .center, spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    StudioEyebrow(title: "Made for your next step")
                    Text("Prepare your\npassport photo.")
                        .font(.system(.largeTitle, design: .serif))
                        .tracking(-1)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if !dynamicTypeSize.isAccessibilitySize {
                    StudioPortraitArt()
                        .frame(width: 126, height: 174)
                }
            }

            Text("A little guidance. Clear photo checks.\nThe right file for your application.")
                .font(.subheadline)
                .lineSpacing(3)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink(value: AppRoute.capture(documentID: DocumentCorpus.featured?.id ?? "us-passport")) {
                HStack(spacing: Theme.Spacing.s) {
                    Text("Start US passport photo")
                    Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityIdentifier("library.start")

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(Theme.accent)
                Text("Check your photo free. Pay only to export.")
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var catalogue: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .firstTextBaseline) {
                Text("Choose your document")
                    .font(.title3.weight(.semibold))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if !dynamicTypeSize.isAccessibilitySize {
                    Text("\(DocumentCorpus.countries.count) countries · \(DocumentCorpus.documents.count) workflows")
                        .font(.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ForEach(DocumentCorpus.countries) { group in
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            Text(group.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.inkSecondary)
                            Theme.Rule()
                            Text("\(group.documents.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Theme.inkTertiary)
                        }
                        .accessibilityElement(children: .combine)
                        ForEach(group.documents) { spec in
                            NavigationLink(value: AppRoute.documentDetail(documentID: spec.id)) {
                                DocumentCard(spec: spec)
                            }
                            .buttonStyle(StudioDocumentButtonStyle())
                            .accessibilityIdentifier("library.document.\(spec.id)")
                        }
                    }
                }
            }
        }
    }

    private var process: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                StudioEyebrow(title: "A simple process")
                StudioStepProgress(current: 1)
                Text("See what needs attention before you save.")
                    .font(.system(.title3, design: .serif))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("We check framing and image quality, explain the results, and ask you to confirm what software cannot see.")
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Theme.Rule()
                NavigationLink(value: AppRoute.unlock) {
                    HStack {
                        Text("What’s included in export")
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.right").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Theme.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.unlock")
            }
        }
    }

    private var privacyCard: some View {
        Button { showPrivacy = true } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: "lock.shield")
                    .font(.title3)
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("A private moment. Kept private.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Your photo stays on your device.\nNo account. No tracking. No upload.")
                        .font(.caption)
                        .lineSpacing(2)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 2)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 4)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Independent photo guidance. The issuing authority makes the final decision.")
                .font(.caption)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let verified = DocumentCorpus.documents.first?.verifiedOn {
                Text("Requirements checked \(Format.day(verified))")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
    }
}

private struct StudioDocumentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.press, value: configuration.isPressed)
    }
}

private struct DocumentCard: View {
    let spec: DocumentSpec
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var detail: String {
        if spec.supportsPrintSheet { return "Print at home or a photo shop" }
        if spec.id == "us-visa" { return "For a US visa photo upload" }
        if spec.id == "us-dv-lottery" { return "For a Diversity Visa entry" }
        return "For your online application"
    }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            if !dynamicTypeSize.isAccessibilitySize {
                StudioPortraitArt(style: spec.supportsPrintSheet ? .printSheet : .digital, compact: true)
                    .frame(width: 62, height: 68)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(spec.documentName)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer(minLength: 0)
                        Text(spec.supportsPrintSheet ? "PRINT" : "DIGITAL")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(Theme.inkSecondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(Theme.paperSunk, in: Capsule())
                    }
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(spec.supportsPrintSheet ? "\(spec.printSizeLabel) · 300 DPI" : "\(spec.outputSummaryLabel) · JPEG")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.inkTertiary)
                .padding(.leading, 2)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.rule, lineWidth: 0.7))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
