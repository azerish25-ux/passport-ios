//
//  AnalysisView.swift
//  PassportProof
//
//  On-device diagnosis of the exact prepared crop. Vision work is revision-
//  scoped; visual confirmations update only the cached rule layer.
//

import SwiftUI
import UIKit

@MainActor
struct AnalysisView: View {
    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession
    @Environment(\.dismiss) private var dismiss

    @State private var isMeasuring = true
    @State private var settled = false
    @State private var goToExport = false
    @State private var showExportReview = false
    @State private var filter: FindingFilter = .all

    private enum FindingFilter: String, CaseIterable {
        case all = "All"
        case attention = "Needs attention"
        case passed = "Passed"
    }

    private var result: PhotoAnalysis? {
        guard session.analyzedDocumentID == spec.id else { return nil }
        return session.analysis
    }

    private var visibleFindings: [Finding] {
        guard let result else { return [] }
        switch filter {
        case .all: return result.findings
        case .attention: return result.findings.filter { $0.status != .pass }
        case .passed: return result.findings.filter { $0.status == .pass }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle(title: "Photo check", subtitle: spec.displayName)

                if isMeasuring {
                    measuring
                } else if let result {
                    verdict(result)
                    if let firstFailure = result.failures.first {
                        retakeBanner(firstFailure)
                    }
                    photo(result)
                    visualChecklist
                    findings
                    disclaimer
                } else {
                    noPhoto
                }
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task(id: "\(spec.id)-\(session.revision.uuidString)") { await run() }
        .navigationDestination(isPresented: $goToExport) {
            ExportView(spec: spec)
        }
        .alert("Some checks remain unresolved", isPresented: $showExportReview) {
            Button("Continue to export") { goToExport = true }
            Button("Stay and review", role: .cancel) {}
        } message: {
            Text("The app cannot measure every issuer requirement. Your visual confirmations are recorded for this session, and the issuer makes the final decision.")
        }
    }

    private var measuring: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let image = session.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .opacity(0.72)
                    .accessibilityHidden(true)
            }
            HStack(spacing: Theme.Spacing.m) {
                ProgressView()
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Checking your photo")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Face geometry, lighting, background and output quality — all on this device.")
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(Theme.Spacing.margin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLiveRegion(.polite)
    }

    private func verdict(_ result: PhotoAnalysis) -> some View {
        let presentation = VerdictPresentation(status: result.overall)
        return VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: presentation.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(presentation.tint)
                    .frame(width: 44, height: 44)
                    .background(presentation.tint.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(presentation.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(presentation.message)
                        .typeStyle(Typography.bodySmall)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: Theme.Spacing.s) {
                CountPill(count: result.findings.filter { $0.status == .pass }.count, title: "Passed", tint: Theme.signalPass)
                CountPill(count: result.failures.count, title: "Failed", tint: Theme.signalFail)
                CountPill(count: result.unresolved.count, title: "Review", tint: Theme.signalVerify)
            }
        }
        .padding(Theme.Spacing.l)
        .background(StatusInk.wash(for: result.overall))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20)
                .fill(StatusInk.color(for: result.overall))
                .frame(width: 4)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
        .accessibilityElement(children: .combine)
    }

    private func retakeBanner(_ failure: Finding) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("Retake required before export", systemImage: "camera.rotate")
                .font(.headline)
                .foregroundStyle(Theme.signalFail)
            Text("\(failure.title): \(failure.detail)")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            PrimaryButton(title: "Retake photo") { dismiss() }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.failWash)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    private func photo(_ result: PhotoAnalysis) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Theme.SectionHeader(title: "Measured crop", trailing: "\(Int(result.imagePixelSize.width)) × \(Int(result.imagePixelSize.height)) px")
            if let image = session.image {
                FaceOverlayView(
                    image: image,
                    geometry: result.geometry,
                    background: result.background,
                    spec: spec
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityHidden(true)
                .accessibilityElement(children: .ignore)
            }
            Text(result.geometry == nil
                 ? "No reliable face geometry was found. Retake with one unobstructed face in clear light."
                 : "Overlay shows the measured face, crown estimate and background regions. Decorative lines are hidden from VoiceOver.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.l)
    }

    private var visualChecklist: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Your visual check")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text("Some requirements need human judgement. Confirm each item against the photo above; these checks update instantly.")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ConfirmationRow(
                    title: "Expression and eyes",
                    detail: spec.expressionRequirement,
                    isOn: reviewBinding(\.expressionConfirmed)
                )
                Theme.Rule().padding(.leading, 44)
                ConfirmationRow(
                    title: "Glasses and visibility",
                    detail: spec.glassesRequirement,
                    isOn: reviewBinding(\.glassesConfirmed)
                )
                Theme.Rule().padding(.leading, 44)
                ConfirmationRow(
                    title: "Recent photograph",
                    detail: "Taken within the last \(Format.decimal(spec.maximumPhotoAgeMonths)) months and reflects your current appearance",
                    isOn: reviewBinding(\.recentPhotoConfirmed)
                )
                Theme.Rule().padding(.leading, 44)
                ConfirmationRow(
                    title: "Original source",
                    detail: "No filters, retouching, background replacement or digital alteration before this geometric crop",
                    isOn: reviewBinding(\.originalUneditedConfirmed)
                )
            }
            .background(Theme.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.rule, lineWidth: 0.5)
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
        .accessibilityIdentifier("analysis.visualChecklist")
    }

    private var findings: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack {
                Text("Detailed findings")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(visibleFindings.count)")
                    .typeStyle(Typography.tabular)
                    .foregroundStyle(Theme.inkSecondary)
            }

            Picker("Filter findings", selection: $filter) {
                ForEach(FindingFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("analysis.filter")

            if visibleFindings.isEmpty {
                ContentUnavailableView(
                    "Nothing in this view",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Choose another filter to see the remaining checks.")
                )
                .frame(minHeight: 180)
            } else {
                VStack(spacing: Theme.Spacing.s) {
                    ForEach(Array(visibleFindings.enumerated()), id: \.element.id) { index, finding in
                        FindingRow(
                            finding: finding,
                            verifiedOn: spec.verifiedOn,
                            isSettled: settled,
                            index: index
                        )
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
    }

    private var disclaimer: some View {
        Label("Informational diagnosis only. PassportProof does not decide whether a document will be issued, and photos never leave this device during analysis.", systemImage: "info.circle")
            .typeStyle(Typography.meta)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.xl)
    }

    private var noPhoto: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ContentUnavailableView(
                "No photo in this session",
                systemImage: "photo.on.rectangle.angled",
                description: Text("For privacy, photos stay in memory and are removed when the session ends.")
            )
            NavigationLink(value: AppRoute.capture(documentID: spec.id)) {
                Text("Choose a photo")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: true))
        }
        .padding(Theme.Spacing.margin)
    }

    private var bottomBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if let result, !result.failures.isEmpty {
                PrimaryButton(title: "Retake photo") { dismiss() }
            } else {
                PrimaryButton(
                    title: "Continue to export",
                    isEnabled: !isMeasuring && session.canExport(for: spec)
                ) {
                    if result?.unresolved.isEmpty == false {
                        showExportReview = true
                    } else {
                        goToExport = true
                    }
                }
                if !isMeasuring, let result, result.failures.isEmpty, !session.review.allConfirmed {
                    Text("Complete all four visual checks to continue.")
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
        .background(Theme.paperRaised)
        .overlay(alignment: .top) { Theme.Rule() }
    }

    private func reviewBinding(_ keyPath: WritableKeyPath<PhotoReview, Bool>) -> Binding<Bool> {
        Binding(
            get: { session.review[keyPath: keyPath] },
            set: { value in
                var review = session.review
                review[keyPath: keyPath] = value
                session.updateReview(review)
            }
        )
    }

    private func run() async {
        if let cached = session.analysis,
           session.analyzedDocumentID == spec.id,
           cached.review == session.review {
            isMeasuring = false
            settled = true
            return
        }

        guard let cgImage = session.cgImage else {
            isMeasuring = false
            return
        }

        isMeasuring = true
        settled = false
        let revision = session.revision
        let spec = self.spec
        let captureDate = session.captureDate
        let review = session.review
        let value = await Task.detached(priority: .userInitiated) {
            ValidationEngine.analyze(image: cgImage, spec: spec, captureDate: captureDate, review: review)
        }.value

        guard !Task.isCancelled, session.revision == revision else { return }
        session.store(value, for: spec.id)
        isMeasuring = false
        await Task.yield()
        settled = true
        UINotificationFeedbackGenerator().notificationOccurred(
            value.failures.isEmpty ? .success : .error
        )
    }
}

private struct VerdictPresentation {
    let title: String
    let message: String
    let icon: String
    let tint: Color

    init(status: FindingStatus) {
        switch status {
        case .pass:
            title = "Checks complete"
            message = "Every applicable check is inside its requirement or has been visually confirmed."
            icon = "checkmark.circle.fill"
            tint = Theme.signalPass
        case .fail:
            title = "This photo needs work"
            message = "At least one requirement is outside its limit. Export stays locked until you retake it."
            icon = "exclamationmark.circle.fill"
            tint = Theme.signalFail
        case .cannotVerify:
            title = "Review the remaining checks"
            message = "Nothing has failed, but some items need your judgement before you continue."
            icon = "eye.circle.fill"
            tint = Theme.signalVerify
        }
    }
}

private struct CountPill: View {
    let count: Int
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text("\(count) \(title)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Theme.paperRaised.opacity(0.74), in: Capsule())
    }
}

private struct ConfirmationRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
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
        .tint(Theme.accent)
        .padding(Theme.Spacing.m)
        .frame(minHeight: 64)
        .accessibilityHint(isOn ? "Confirmed for this session" : "Not yet confirmed")
    }
}
