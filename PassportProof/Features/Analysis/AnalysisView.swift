import SwiftUI
import UIKit

/// Analysis always describes the accepted pixels. Reframing opens the retained
/// original and commits a new revision only when the user accepts the edit.
@MainActor
struct AnalysisView: View {
    let spec: DocumentSpec
    @EnvironmentObject private var session: PhotoSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isMeasuring = true
    @State private var settled = false
    @State private var goToExport = false
    @State private var showExportReview = false
    @State private var showMeasurements = false
    @State private var editContext: PhotoEditContext?
    @State private var manualContext: ManualFramingEditContext?
    @State private var filter: FindingFilter = .attention

    private enum FindingFilter: String, CaseIterable {
        case attention = "To review"
        case all = "All checks"
        case passed = "Passed"
    }
    private var result: PhotoAnalysis? {
        guard session.hasPhoto(for: spec), session.analyzedDocumentID == spec.id else { return nil }
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
    private var confirmedCount: Int {
        [session.review.expressionConfirmed, session.review.glassesConfirmed,
         session.review.recentPhotoConfirmed, session.review.originalUneditedConfirmed].filter { $0 }.count
    }
    private var manualRecord: ManualFramingRecord? { session.manualFraming(for: spec) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                StudioStepProgress(current: 2)
                VStack(alignment: .leading, spacing: 7) {
                    StudioEyebrow(title: "\(spec.documentName) · Photo review")
                    Text("A closer look.")
                        .font(.system(.largeTitle, design: .serif, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("Your photo, checked on your device. Review the details before you export.")
                        .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isMeasuring {
                    measuring
                } else if let result {
                    photo(result)
                    verdict(result)
                    if let failure = result.failures.first { improvement(failure) }
                    visualChecklist
                    findings
                    Label("These checks help you prepare a photo. The issuing authority makes the final decision.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    noPhoto
                }
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Theme.paper)
        .navigationTitle("Photo review")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task(id: "\(spec.id)-\(session.revision.uuidString)") { await run() }
        .navigationDestination(isPresented: $goToExport) { ExportView(spec: spec) }
        .fullScreenCover(item: $editContext) { context in
            CropEditorView(context: context, spec: spec, onAccept: { crop in
                _ = session.acceptCrop(crop, for: spec, captureDate: context.captureDate)
                editContext = nil
            }, onCancel: { editContext = nil })
        }
        .fullScreenCover(item: $manualContext) { context in
            ManualFramingView(image: context.image, spec: spec, revision: context.revision,
                              existing: context.existing, onConfirm: { guides, review, revision in
                let saved = session.confirmManualFraming(guides: guides, review: review,
                                                        for: spec, revision: revision)
                if saved { manualContext = nil }
                return saved
            }, onCancel: { manualContext = nil })
            .dynamicTypeSize(dynamicTypeSize)
        }
        .alert(manualRecord == nil ? "Review the uncertain measurements" : "Review the unverified checks", isPresented: $showExportReview) {
            Button("Continue to export") { goToExport = true }
            Button("Keep reviewing", role: .cancel) {}
        } message: {
            if manualRecord != nil {
                Text("Framing comes from your manual guides. Automatic face measurements remain unavailable. Still unverified: \(result?.unresolved.map(\.title).joined(separator: ", ") ?? "some photo requirements"). Export formats the photo; it does not certify acceptance.")
            } else {
                Text("Still uncertain: \(result?.unresolved.map(\.title).joined(separator: ", ") ?? "some measurements"). Compare these with the issuer's guidance. Export formats the photo; it does not certify acceptance.")
            }
        }
    }

    private var measuring: some View {
        StudioCard {
            VStack(spacing: 18) {
                if let image = session.image, session.hasPhoto(for: spec) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .frame(maxHeight: 290)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                }
                HStack(spacing: 12) {
                    ProgressView().tint(Theme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Checking the details…").font(.headline).foregroundStyle(Theme.ink)
                        Text("Framing, background, lighting and resolution.")
                            .font(.footnote).foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityIdentifier("analysis.measuring")
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func photo(_ analysis: PhotoAnalysis) -> some View {
        StudioCard(padding: 16) {
            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    StudioEyebrow(title: "Your prepared photo")
                    Text("\(Int(analysis.imagePixelSize.width)) × \(Int(analysis.imagePixelSize.height)) px")
                        .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSecondary)
                    if analysis.geometry == nil {
                        if manualRecord != nil {
                            Text("Manually framed")
                                .font(.caption.weight(.semibold)).foregroundStyle(Theme.signalVerify)
                                .accessibilityIdentifier("analysis.manualStatus")
                        } else {
                            Text("Automatic measurements unavailable")
                                .font(.caption.weight(.medium)).foregroundStyle(Theme.signalVerify)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("analysis.automaticUnavailable")
                        }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if let image = session.image {
                    Group {
                        if showMeasurements {
                            FaceOverlayView(image: image, geometry: analysis.geometry,
                                            background: analysis.background, spec: spec)
                        } else {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("The exact crop used for these checks and your export")
                    .accessibilityIdentifier("analysis.photo")
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { editButton; photoGuideButton(analysis) }
                    VStack(spacing: 8) { editButton; photoGuideButton(analysis) }
                }
            }
        }
    }
    @ViewBuilder private func photoGuideButton(_ analysis: PhotoAnalysis) -> some View {
        // When automatic measurement is unavailable the framing action lives in
        // the pinned footer, where it is always reachable. Repeating the same
        // primary action twice on one screen was the old behaviour.
        if analysis.geometry == nil && analysis.failures.isEmpty {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { showMeasurements.toggle() }
            } label: {
                Label(showMeasurements ? "Hide guides" : "Show guides", systemImage: "viewfinder")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain).foregroundStyle(Theme.inkSecondary)
            .disabled(isMeasuring)
            .accessibilityIdentifier("analysis.guides")
        } else {
            measurementsButton
        }
    }
    private var editButton: some View {
        Button { editContext = session.cropEditingContext(for: spec) } label: {
            Label("Edit framing", systemImage: "crop.rotate")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).foregroundStyle(Theme.accent)
        .disabled(session.cropEditingContext(for: spec) == nil)
        .accessibilityIdentifier("analysis.editCrop")
    }
    private var measurementsButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { showMeasurements.toggle() }
        } label: {
            Label(showMeasurements ? "Hide guides" : "Show guides", systemImage: "viewfinder")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain).foregroundStyle(Theme.inkSecondary)
        .accessibilityValue(showMeasurements ? "Visible" : "Hidden")
        .accessibilityIdentifier("analysis.guides")
    }

    private func verdict(_ analysis: PhotoAnalysis) -> some View {
        let presentation = VerdictPresentation(status: analysis.overall,
                                               hasFaceMeasurements: analysis.geometry != nil,
                                               isManuallyFramed: manualRecord != nil)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: presentation.icon).font(.title2)
                    .foregroundStyle(presentation.tint).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(presentation.title).font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                    Text(presentation.message).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { counts(analysis) }
                VStack(alignment: .leading, spacing: 8) { counts(analysis) }
            }
        }
        .accessibilityIdentifier("analysis.verdict")
    }
    @ViewBuilder private func counts(_ analysis: PhotoAnalysis) -> some View {
        CountPill(count: analysis.findings.filter { $0.status == .pass }.count, title: "passed", tint: Theme.signalPass)
        CountPill(count: analysis.failures.count, title: "to fix", tint: Theme.signalFail)
        CountPill(count: analysis.unresolved.count, title: "to review", tint: Theme.signalVerify)
    }
    private func improvement(_ finding: Finding) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(finding.title, systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.signalFail)
            Text(finding.detail).font(.footnote).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Adjust the framing below, or return to choose another original photo.")
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.failWash, in: RoundedRectangle(cornerRadius: 18))
    }

    private var visualChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Your final look").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                    .accessibilityIdentifier("analysis.visualChecklist")
                Text("\(confirmedCount) of 4 confirmed").font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(confirmedCount == 4 ? Theme.signalPass : Theme.inkSecondary)
            }
            Text("Check each statement against the original photo. These details need your judgement.")
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            StudioCard(padding: 4) {
                VStack(spacing: 0) {
                    ConfirmationRow(title: "Expression & eyes", detail: spec.expressionRequirement,
                                    isOn: reviewBinding(\.expressionConfirmed), identifier: "review.expression")
                    Theme.Rule().padding(.horizontal, 12)
                    ConfirmationRow(title: "Glasses & visibility", detail: spec.glassesRequirement,
                                    isOn: reviewBinding(\.glassesConfirmed), identifier: "review.glasses")
                    Theme.Rule().padding(.horizontal, 12)
                    ConfirmationRow(title: "A recent photo", detail: "Taken within \(Format.decimal(spec.maximumPhotoAgeMonths)) months and shows your current appearance.",
                                    isOn: reviewBinding(\.recentPhotoConfirmed), identifier: "review.recent")
                    Theme.Rule().padding(.horizontal, 12)
                    ConfirmationRow(title: "An unaltered original", detail: "No filters, retouching or background replacement before this crop.",
                                    isOn: reviewBinding(\.originalUneditedConfirmed), identifier: "review.original")
                }
            }
        }
    }
    private var findings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("The details").font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(visibleFindings.count) checks").font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    filterPicker.pickerStyle(.menu).frame(minHeight: 44)
                } else {
                    filterPicker.pickerStyle(.segmented)
                }
            }.accessibilityIdentifier("analysis.filter")
            if visibleFindings.isEmpty {
                Label("Nothing to review in this group.", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(Theme.signalPass)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(visibleFindings.enumerated()), id: \.element.id) { index, finding in
                        FindingRow(finding: finding, verifiedOn: spec.verifiedOn, isSettled: settled, index: index)
                    }
                }
            }
        }
    }
    private var filterPicker: some View {
        Picker("Filter findings", selection: $filter) {
            ForEach(FindingFilter.allCases, id: \.self) { item in Text(item.rawValue).tag(item) }
        }
    }

    private var noPhoto: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: 16) {
                StudioPortraitArt(style: .portrait, compact: true).frame(height: 140)
                Text("Start with a photo.").font(.title2.weight(.semibold)).foregroundStyle(Theme.ink)
                Text("Choose an original for this document. Your images stay in this session.")
                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                NavigationLink(value: AppRoute.capture(documentID: spec.id)) { Text("Choose a photo") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let analysis = result, !analysis.failures.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { correctionActions }
                    VStack(spacing: 8) { correctionActions }
                }
            } else if !isMeasuring, let analysis = result, analysis.geometry == nil, manualRecord == nil {
                PrimaryButton(title: "Place framing guides", action: openManualFraming)
                    .accessibilityIdentifier("analysis.manualStart")
                Text("Four guides on your photo. Takes about 15 seconds.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                PrimaryButton(title: "Continue to export", isEnabled: !isMeasuring && session.canExport(for: spec)) {
                    if result?.unresolved.isEmpty == false { showExportReview = true }
                    else { goToExport = true }
                }
                .accessibilityIdentifier("analysis.continue")
                if !isMeasuring && result != nil && confirmedCount < 4 {
                    Text("Confirm the \(4 - confirmedCount) remaining visual checks.")
                        .font(.caption).foregroundStyle(Theme.inkSecondary)
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.margin).padding(.top, 12).padding(.bottom, 12)
        .background(Theme.paperRaised)
        .overlay(alignment: .top) { Theme.Rule() }
    }
    @ViewBuilder private var correctionActions: some View {
        Button { dismiss() } label: { Text("Choose another").frame(minHeight: 44) }
            .font(.subheadline.weight(.medium)).foregroundStyle(Theme.inkSecondary)
            .accessibilityIdentifier("analysis.chooseAnother")
        PrimaryButton(title: "Adjust framing", isEnabled: session.cropEditingContext(for: spec) != nil) {
            editContext = session.cropEditingContext(for: spec)
        }.accessibilityIdentifier("analysis.adjust")
    }
    private func openManualFraming() {
        guard !isMeasuring, let analysis = result, analysis.geometry == nil,
              analysis.failures.isEmpty, let image = session.image else { return }
        manualContext = ManualFramingEditContext(image: image, revision: session.revision,
                                                existing: manualRecord)
    }
    private func reviewBinding(_ keyPath: WritableKeyPath<PhotoReview, Bool>) -> Binding<Bool> {
        Binding(get: { session.review[keyPath: keyPath] }, set: { value in
            var review = session.review
            review[keyPath: keyPath] = value
            session.updateReview(review)
        })
    }
    private func run() async {
        guard session.hasPhoto(for: spec), let image = session.cgImage else {
            isMeasuring = false
            return
        }
        if let cached = result, cached.review == session.review {
            isMeasuring = false
            settled = true
            return
        }
        isMeasuring = true
        settled = false
        let revision = session.revision
        let spec = self.spec
        let captureDate = session.captureDate
        let review = session.review
        let analysis = await Task.detached(priority: .userInitiated) {
            ValidationEngine.analyze(image: image, spec: spec, captureDate: captureDate, review: review)
        }.value
        guard !Task.isCancelled, session.revision == revision else { return }
        session.store(analysis, for: spec.id, revision: revision)
        isMeasuring = false
        await Task.yield()
        settled = true
    }
}

private struct ManualFramingEditContext: Identifiable {
    let id = UUID()
    let image: UIImage
    let revision: UUID
    let existing: ManualFramingRecord?
}

private struct VerdictPresentation {
    let title: String
    let message: String
    let icon: String
    let tint: Color
    init(status: FindingStatus, hasFaceMeasurements: Bool, isManuallyFramed: Bool) {
        // An objective failure remains blocking even if automatic geometry is
        // also unavailable. Manual framing never overrides that result.
        if status == .fail {
            title = "A few details to adjust"
            message = "Review the highlighted findings before exporting. Your original is available to reframe."
            icon = "exclamationmark.circle.fill"; tint = Theme.signalFail
            return
        }
        guard hasFaceMeasurements else {
            title = isManuallyFramed ? "Your guides set the framing" : "Check the framing yourself"
            message = isManuallyFramed
                ? "You confirmed the guide positions. Automatic face measurements remain unavailable, and the unresolved checks below still need your judgment."
                : "Automatic face measurement isn’t reliable for this photo. Place four guides on your photo instead — the same published ranges are checked exactly — or reframe and try again."
            icon = "slider.horizontal.3"; tint = Theme.signalVerify
            return
        }
        switch status {
        case .pass:
            title = "Ready for your next step"
            message = "Measured checks passed and your visual review is complete."
            icon = "checkmark.circle.fill"; tint = Theme.signalPass
        case .fail:
            title = "A few details to adjust"
            message = "Review the highlighted findings before exporting. Your original is available to reframe."
            icon = "exclamationmark.circle.fill"; tint = Theme.signalFail
        case .cannotVerify:
            title = "Give it your final look"
            message = "Some details need your review. Uncertain measurements stay clearly marked."
            icon = "eye.circle.fill"; tint = Theme.signalVerify
        }
    }
}
private struct CountPill: View {
    let count: Int
    let title: String
    let tint: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text("\(count) \(title)").font(.caption.weight(.medium)).foregroundStyle(Theme.inkSecondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Theme.paperRaised, in: Capsule())
    }
}
private struct ConfirmationRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let identifier: String
    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.footnote).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.accent).padding(14).frame(minHeight: 64)
        .accessibilityIdentifier(identifier)
        .accessibilityHint(isOn ? "Confirmed for this photo" : "Confirm after checking the original photo")
    }
}
