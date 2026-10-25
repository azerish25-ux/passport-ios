//
//  DocumentLibraryView.swift
//  PassportProof
//
//  A focused production catalogue: only complete workflows, no placeholders.
//

import SwiftUI

struct DocumentLibraryView: View {
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                hero
                catalogue
                process
                privacyCard
                footer
            }
        }
        .background(Theme.paper)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPrivacy) {
            NavigationStack { PrivacyView() }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Theme.onInk)
                .frame(width: 42, height: 42)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text("PassportProof")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text("PRIVATE PHOTO STUDIO")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.1)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Button {
                showPrivacy = true
            } label: {
                Image(systemName: "lock.shield")
                    .font(.title3)
                    .foregroundStyle(Theme.ink)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Privacy and data use")
            .accessibilityIdentifier("library.privacy")
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack {
                Label("ON-DEVICE", systemImage: "checkmark.shield.fill")
                    .font(.caption2.weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Theme.accent, in: Capsule())
                Spacer()
                Image(systemName: "viewfinder")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.heroInk.opacity(0.16))
                    .accessibilityHidden(true)
            }

            Text("A better photo,\nbefore you submit.")
                .font(.largeTitle.weight(.bold))
                .tracking(-0.8)
                .foregroundStyle(Theme.heroInk)
                .fixedSize(horizontal: false, vertical: true)

            Text("Guided capture, transparent checks and precisely formatted exports for supported US document workflows.")
                .font(.body)
                .foregroundStyle(Theme.heroMuted)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink(value: AppRoute.capture(documentID: "us-passport")) {
                HStack {
                    Text("Start a photo")
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccentButtonStyle())
            .accessibilityIdentifier("library.start")

            Text("US Passport starts first. Choose another workflow below.")
                .font(.caption)
                .foregroundStyle(Theme.heroMuted)
        }
        .padding(Theme.Spacing.xl)
        .background(
            LinearGradient(
                colors: [Theme.heroTop, Theme.heroBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.l)
    }

    private var catalogue: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Choose your document")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(DocumentCorpus.documents.count) workflows")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
            }

            VStack(spacing: Theme.Spacing.m) {
                ForEach(DocumentCorpus.documents) { spec in
                    NavigationLink(value: AppRoute.documentDetail(documentID: spec.id)) {
                        DocumentCard(spec: spec)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("library.document.\(spec.id)")
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xxl)
    }

    private var process: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("From camera to confident file")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)

            ProcessStep(number: "01", title: "Frame it", detail: "Use live camera guidance or choose an original photo, then review one precise crop.")
            ProcessStep(number: "02", title: "Check it", detail: "See measured results and confirm the visual requirements software cannot prove.")
            ProcessStep(number: "03", title: "Export it", detail: "Create a print sheet or digital file from the exact photo you reviewed.")
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xxl)
    }

    private var privacyCard: some View {
        Button {
            showPrivacy = true
        } label: {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: "lock.shield.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Your photo stays yours")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("No account, analytics or upload. Photos are held in memory; share staging is deleted after use.")
                        .typeStyle(Typography.bodySmall)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Read our privacy approach")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, Theme.Spacing.xs)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.inkTertiary)
            }
            .padding(Theme.Spacing.l)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xxl)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            NavigationLink(value: AppRoute.unlock) {
                Label("View one-time export unlock", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library.unlock")

            Text("Informational diagnosis only. PassportProof is independent and not affiliated with any government. The issuing authority always makes the final decision.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Rules verified \(Format.day(DocumentCorpus.documents[0].verifiedOn)) · Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.caption)
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.xxxl)
    }
}

private struct DocumentCard: View {
    let spec: DocumentSpec

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            Text(spec.countryCode)
                .font(.system(.headline, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 52, height: 52)
                .background(Theme.paperSunk, in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(spacing: Theme.Spacing.s) {
                    Text(spec.documentName)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text(spec.workflow.shortTitle)
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Theme.accent.opacity(0.1), in: Capsule())
                }
                Text(spec.supportsPrintSheet
                     ? "2 × 2 in print sheet · 300 DPI"
                     : "\(spec.widthPixels) × \(spec.heightPixels) JPEG · up to \(spec.maximumFileSizeBytes.map { $0 / 1_000 } ?? 0) kB")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Spacing.s)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.inkTertiary)
        }
        .padding(Theme.Spacing.l)
        .background(Theme.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.rule, lineWidth: 0.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ProcessStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Text(number)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accent.opacity(0.1), in: Circle())
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
