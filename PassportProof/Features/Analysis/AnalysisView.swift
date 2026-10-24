//
//  AnalysisView.swift
//  PassportProof
//
//  The diagnosis. `ValidationEngine.analyze` is synchronous and CPU-bound, so it
//  runs in a detached task and the result is applied on the main actor.
//
//  The verdict is an instrument readout, not a success banner: one word, the
//  count line, and a sentence that says what the word does and does not mean.
//  A failure is unmissable — full-bleed wash, 3pt rail, the first failing rule
//  named — but export stays reachable, quietly.
//

import SwiftUI
import UIKit

@MainActor
struct AnalysisView: View {

    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession
    @Environment(\.dismiss) private var dismiss

    @State private var result: PhotoAnalysis?
    @State private var isMeasuring = true
    @State private var settled = false
    @State private var goToExport = false

    private var hasFailures: Bool {
        result?.failures.isEmpty == false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ScreenTitle(title: "Diagnose", subtitle: spec.displayName)

                if isMeasuring {
                    measuring
                } else if let result {
                    verdict(result)
                    if let firstFailure = result.failures.first {
                        retakeBanner(firstFailure)
                    }
                    photo(result)
                    findings(result)
                    disclaimer
                } else {
                    noPhoto
                }

                Spacer(minLength: Theme.Spacing.xxxl)
            }
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .task(id: spec.id) {
            await run()
        }
        .navigationDestination(isPresented: $goToExport) {
            ExportView(spec: spec)
        }
    }

    // MARK: Measuring

    private var measuring: some View {
        VStack(alignment: .leading, spacing: 0) {
            Theme.SectionHeader(title: "Result")

            HStack(alignment: .firstTextBaseline) {
                Typography.measurement.text("MEASURING")
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Spacer(minLength: Theme.Spacing.m)
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.l)

            Text("Eleven rules, evaluated on this device. Nothing is uploaded and nothing is stored.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: Verdict

    private func verdict(_ result: PhotoAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Theme.SectionHeader(title: "Result")

            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Typography.measurement.text(overallWord(result.overall))
                    .foregroundStyle(StatusInk.color(for: result.overall))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Spacer(minLength: Theme.Spacing.s)

                Text(countLine(result))
                    .typeStyle(Typography.tabular)
                    .foregroundStyle(Theme.inkTertiary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.l)

            Text(overallSentence(result.overall))
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, Theme.Spacing.s)
                .padding(.bottom, Theme.Spacing.l)
        }
    }

    private func overallWord(_ status: FindingStatus) -> String {
        switch status {
        case .pass:
            return "PASS"
        case .fail:
            return "FAIL"
        case .cannotVerify:
            return "CANNOT VERIFY"
        }
    }

    private func overallSentence(_ status: FindingStatus) -> String {
        switch status {
        case .pass:
            return "Every rule that could be measured is inside tolerance. Tolerance is not a decision: the document is still examined by the issuer."
        case .fail:
            return "At least one rule is outside tolerance. This is a diagnosis of the photograph, not a finding about the document."
        case .cannotVerify:
            return "At least one rule could not be resolved. Some rules exist only for documents that publish them; others need a cleaner background or a better-lit frame. The app reports that rather than guessing."
        }
    }

    private func countLine(_ result: PhotoAnalysis) -> String {
        let pass = result.findings.filter { $0.status == .pass }.count
        let fail = result.findings.filter { $0.status == .fail }.count
        let verify = result.findings.filter { $0.status == .cannotVerify }.count

        return "\(pass) PASS · \(fail) FAIL · \(verify) CANNOT VERIFY"
    }

    // MARK: Retake banner

    private func retakeBanner(_ failure: Finding) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Typography.findingLabel.text("Retake required")
                .foregroundStyle(Theme.signalFail)

            Text("\(failure.title) — \(failure.detail)")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Retake photo") {
                dismiss()
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Theme.Stroke.statusRail + Theme.Spacing.margin)
        .padding(.trailing, Theme.Spacing.margin)
        .padding(.vertical, Theme.Spacing.l)
        .background(Theme.failWash)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Theme.signalFail)
                .frame(width: Theme.Stroke.statusRail)
        }
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: Photo

    @ViewBuilder
    private func photo(_ result: PhotoAnalysis) -> some View {
        if let image = session.image {
            FaceOverlayView(
                image: image,
                geometry: result.geometry,
                background: result.background,
                spec: spec
            )
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.xl)

            Text("Crown is measured to the top of the skull; the envelope is the top of the hair. When the two disagree the head-height rule returns CANNOT VERIFY.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Spacing.margin)
                .padding(.top, Theme.Spacing.s)
        }
    }

    // MARK: Findings

    private func findings(_ result: PhotoAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Theme.SectionHeader(
                title: "Findings",
                trailing: "\(result.findings.count)"
            )

            ForEach(Array(result.findings.indices), id: \.self) { index in
                let finding = result.findings[index]

                FindingRow(
                    finding: finding,
                    verifiedOn: spec.verifiedOn,
                    isSettled: settled,
                    index: index
                )

                Theme.Rule()
            }
        }
    }

    // MARK: Disclaimer

    private var disclaimer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Theme.Rule(color: Theme.ruleStrong, weight: Theme.Stroke.rule)

            Text("Informational diagnosis. This app does not determine whether a document will be issued.")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("The photograph is held in memory for this session and is never uploaded or written to storage.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.xl)
    }

    // MARK: No photo

    private var noPhoto: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Theme.SectionHeader(title: "Result")

            Text("No photograph in this session.")
                .typeStyle(Typography.body)
                .foregroundStyle(Theme.ink)

            Text("A photograph is held in memory only, so returning to this screen after the session ends means capturing again.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            NavigationLink(value: AppRoute.capture(documentID: spec.id)) {
                Text("Go to capture")
            }
            .buttonStyle(PrimaryButtonStyle(isEnabled: true))
            .padding(.top, Theme.Spacing.m)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Theme.Rule()

            Group {
                if hasFailures {
                    SecondaryAction(title: "Export anyway") {
                        goToExport = true
                    }
                } else {
                    PrimaryButton(title: "Continue to export", isEnabled: result != nil) {
                        goToExport = true
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.paper)
    }

    // MARK: Work

    @MainActor
    private func run() async {
        if let cached = session.analysis, session.analyzedDocumentID == spec.id {
            result = cached
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

        let spec = self.spec
        let captureDate = session.captureDate
        let value = await Task.detached(priority: .userInitiated) {
            ValidationEngine.analyze(image: cgImage, spec: spec, captureDate: captureDate)
        }.value

        result = value
        session.store(value, for: spec.id)
        isMeasuring = false

        await Task.yield()
        settled = true

        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}
