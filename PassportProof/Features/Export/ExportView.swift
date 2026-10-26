//
//  ExportView.swift
//  PassportProof
//
//  Preview and export the reviewed crop. The print preview is rasterized from
//  the actual PDF renderer, so paper margins and photo placement stay honest.
//

import SwiftUI
import UIKit
import CoreGraphics

@MainActor
struct ExportView: View {
    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession
    @EnvironmentObject private var entitlements: EntitlementStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var share: ShareItem?
    @State private var stagedURL: URL?
    @State private var failure: String?
    @State private var preparedSummary: String?
    @State private var isExporting = false
    @State private var exportTask: Task<Void, Never>?
    @State private var goToUnlock = false
    @State private var sheetPreview: UIImage?
    @State private var isPreparingPreview = false

    private var layout: PrintSheetLayout { session.layout }
    private var plan: PrintPlan { PrintPlan(layout: layout, spec: spec) }
    private var isReady: Bool { session.canExport(for: spec) }
    private var hasExportAccess: Bool { entitlements.canExport }
    private var isManuallyFramed: Bool { session.manualFraming(for: spec) != nil }
    private var reviewCount: Int { session.analysis?.unresolved.count ?? 0 }
    private var previewKey: String { "\(session.revision.uuidString)-\(spec.id)-\(layout.rawValue)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                StudioStepProgress(current: 3)
                introduction
                preview
                readinessCard
                if spec.supportsPrintSheet { printContent } else { digitalContent }
                outputSummary
                if let failure { failureCard(failure) }
                if !hasExportAccess { lockedCard }
                privacyFooter
            }
            .padding(Theme.Spacing.margin)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { exportBar }
        .sheet(item: $share, onDismiss: { cleanStaging() }) { item in
            ShareSheet(items: [item.url]) { finishSharing(item.url) }
        }
        .navigationDestination(isPresented: $goToUnlock) { UnlockView() }
        .task(id: previewKey) { await preparePreview() }
        .onChange(of: session.revision) { _, _ in
            preparedSummary = nil
            failure = nil
        }
        .onChange(of: session.layout) { _, _ in preparedSummary = nil }
        .onDisappear {
            exportTask?.cancel()
            if share == nil { cleanStaging() }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            StudioEyebrow(title: "The finishing step")
            Text(isReady ? (isManuallyFramed ? "Ready to format." : (spec.supportsPrintSheet ? "Ready for paper." : "Ready for your application.")) : "Prepare your file.")
                .font(.system(.largeTitle, design: .serif))
                .tracking(-0.7)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(spec.supportsPrintSheet
                 ? "Choose a sheet. Keep the size exact."
                 : "The right dimensions and file format, from your reviewed photo.")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if isManuallyFramed {
                Label("Manually framed", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.signalVerify)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.verifyWash, in: Capsule())
                    .accessibilityIdentifier("export.manualStatus")
                Text("Framing comes from guides you placed. Automatic face measurements were unavailable.")
                    .font(.footnote)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var preview: some View {
        StudioCard(padding: 16) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .firstTextBaseline) {
                    Text(spec.supportsPrintSheet ? "Your print sheet" : "Your photo")
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                        .accessibilityIdentifier("export.preview")
                    Spacer(minLength: 8)
                    Text(spec.supportsPrintSheet ? "PDF" : "JPEG")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.sageWash, in: Capsule())
                }
                Group {
                    if session.hasPhoto(for: spec), let image = session.image {
                        if spec.supportsPrintSheet {
                            if let sheetPreview {
                                Image(uiImage: sheetPreview)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 330)
                                    .accessibilityLabel("Preview of the actual \(layout.title) PDF with \(plan.count) copies of your reviewed photo")
                            } else if isPreparingPreview {
                                ProgressView("Preparing sheet preview…")
                                    .tint(Theme.accent)
                                    .font(.caption)
                                    .frame(minHeight: 220)
                            } else {
                                Label("A print preview could not be created from this crop.", systemImage: "doc")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(minHeight: 160)
                            }
                        } else {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 290, maxHeight: 290)
                                .accessibilityLabel("Your complete reviewed crop, without any additional cropping")
                        }
                    } else {
                        Label("Choose and check a photo to see your preview.", systemImage: "photo")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(minHeight: 160)
                    }
                }
                .padding(Theme.Spacing.l)
                .frame(maxWidth: .infinity)
                .background(Theme.paperSunk, in: RoundedRectangle(cornerRadius: 14))

                Text(spec.supportsPrintSheet
                     ? "\(layout.title) · \(plan.count) photos · print at 100%"
                     : "\(spec.widthPixels) × \(spec.heightPixels) px · your reviewed crop")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(spec.supportsPrintSheet
                     ? "This preview uses the same PDF renderer as your export."
                     : "The JPEG is encoded and its file size checked when you export.")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var readinessCard: some View {
        let needsAttention = !isReady || reviewCount > 0
        return HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: needsAttention ? "exclamationmark.circle" : "checkmark.circle")
                .font(.title3)
                .foregroundStyle(needsAttention ? Theme.signalVerify : Theme.signalPass)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(!isReady ? "Photo checks need attention" : (isManuallyFramed ? "Your guides. Your final review." : (reviewCount > 0 ? "Ready, with review notes" : "Ready to export")))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(!isReady
                     ? "Return to your photo check and address failed rules and outstanding visual confirmations."
                     : (isManuallyFramed
                        ? "Your guide positions meet this workflow’s size ranges. Automatic face and quality checks remain unverified; compare your photo with the issuer’s guidance before submitting."
                        : (reviewCount > 0
                        ? "\(reviewCount) check\(reviewCount == 1 ? "" : "s") still needs your judgment. Review those notes before submitting."
                        : "Your required confirmations are complete and no measured rule is failing. The issuer makes the final decision.")))
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if reviewCount > 0 && isReady {
                    SecondaryAction(title: "Read photo check notes") { dismiss() }
                }
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(needsAttention ? Theme.verifyWash : Theme.sageWash, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Printed photo

    private var printContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("Choose your paper")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                      ? [GridItem(.flexible())]
                      : [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.s) {
                ForEach(PrintSheetLayout.allCases) { item in
                    LayoutRow(item: item, isSelected: layout == item) {
                        session.layout = item
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    .disabled(isExporting || share != nil)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("Make the printed size count", systemImage: "ruler")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("Print at 100% on photo paper. Switch off “fit to page” and measure the free calibration square before printing your photos.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryAction(title: "Share free calibration page", isEnabled: !isExporting && share == nil) { exportCalibration() }
                    .accessibilityIdentifier("export.calibration")
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sageWash, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        }
    }

    // MARK: Digital photo

    private var digitalContent: some View {
        StudioCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                StudioEyebrow(title: "Your file specification")
                ExportFact(icon: "aspectratio", title: "Dimensions", value: "\(spec.widthPixels) × \(spec.heightPixels) pixels")
                ExportFact(icon: "doc", title: "Format", value: "JPEG · sRGB colour")
                if let maximum = spec.maximumFileSizeBytes {
                    ExportFact(icon: "arrow.down.doc", title: "File limit", value: "\(maximum / 1_000) kB maximum, verified after encoding")
                }
                ExportFact(icon: "crop", title: "Image", value: "Your reviewed crop. No filters or background replacement.")
            }
        }
    }

    private var outputSummary: some View {
        Group {
            if let preparedSummary {
                Label(preparedSummary, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.signalPass)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("export.summary")
    }

    private var lockedCard: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: "lock")
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("One purchase. Unlimited supported exports.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Checks and calibration stay free. Review the current App Store price before you buy.")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryAction(title: hasExportAccess ? "Review export options" : "View export access") { goToUnlock = true }
                    .accessibilityIdentifier("export.unlock")
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 18))
    }

    private var exportBar: some View {
        VStack(spacing: Theme.Spacing.s) {
            PrimaryButton(title: primaryTitle, isEnabled: !isExporting && share == nil) {
                if !isReady { dismiss() }
                else if !hasExportAccess { goToUnlock = true }
                else if spec.supportsPrintSheet { exportPrintSheet() }
                else { exportDigital() }
            }
            .accessibilityIdentifier("export.primary")
            Text(exportBarDetail)
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

    private var primaryTitle: String {
        if isExporting { return "Preparing your file…" }
        if !isReady { return "Return to photo checks" }
        if !hasExportAccess { return "Unlock export" }
        return spec.supportsPrintSheet ? "Export PDF" : "Export JPEG"
    }

    /// Says exactly what the next tap costs. A single-export credit is spent
    /// only after a file has been staged, so this wording never promises more
    /// than the code does.
    private var exportBarDetail: String {
        if !isReady { return "Complete the photo check to prepare your file" }
        if entitlements.isUnlocked { return "Choose where to save or send in the next step" }
        if entitlements.exportCredits == 1 { return "Uses your 1 export credit · no subscription" }
        if entitlements.exportCredits > 1 { return "Uses 1 of your \(entitlements.exportCredits) export credits" }
        return "One-time purchase · no subscription"
    }

    private var privacyFooter: some View {
        Label("Prepared on your device. The temporary share file is removed after sharing; copies you save or send are yours to manage.", systemImage: "lock.shield")
            .font(.caption)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func failureCard(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.subheadline)
            .foregroundStyle(Theme.signalFail)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.failWash, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: Actual PDF preview

    private func preparePreview() async {
        sheetPreview = nil
        isPreparingPreview = false
        guard spec.supportsPrintSheet, session.hasPhoto(for: spec), let photo = session.cgImage else { return }
        isPreparingPreview = true
        let expected = previewKey
        let layout = self.layout
        let spec = self.spec
        let data = await Task.detached(priority: .userInitiated) {
            PrintSheetRenderer.pdfData(photo: photo, layout: layout, spec: spec)
        }.value
        guard !Task.isCancelled, expected == previewKey else { return }
        isPreparingPreview = false
        if let data { sheetPreview = PDFThumbnail.image(from: data, width: 360) }
    }

    // MARK: Actions

    private func exportCalibration() {
        guard !isExporting, share == nil else { return }
        isExporting = true
        failure = nil
        preparedSummary = nil
        let layout = self.layout
        exportTask = Task {
            let data = await Task.detached(priority: .userInitiated) {
                PrintSheetRenderer.calibrationPDFData(layout: layout, spec: spec)
            }.value
            guard !Task.isCancelled else {
                isExporting = false
                return
            }
            isExporting = false
            guard let data else {
                failure = "The calibration sheet could not be rendered. Try another layout."
                return
            }
            stage(data, name: "calibration-\(layout.rawValue)", fileExtension: "pdf")
        }
    }

    private func exportPrintSheet() {
        guard requireReady(), requireExportAccess(), !isExporting else { return }
        guard let photo = session.cgImage else { return }
        isExporting = true
        failure = nil
        preparedSummary = nil
        let revision = session.revision
        let layout = self.layout
        let spec = self.spec
        let unlimited = entitlements.isUnlocked

        exportTask = Task {
            let data = await Task.detached(priority: .userInitiated) {
                PrintSheetRenderer.pdfData(photo: photo, layout: layout, spec: spec)
            }.value
            guard !Task.isCancelled, session.revision == revision,
                  session.canExport(for: spec),
                  unlimited || entitlements.exportCredits > 0,
                  session.layout == layout else {
                isExporting = false
                return
            }
            isExporting = false
            guard let data else {
                failure = "The print sheet could not be rendered from this crop."
                return
            }
            if stage(data, name: "\(spec.id)-\(layout.rawValue)", fileExtension: "pdf") {
                entitlements.consumeExportCredit()
                preparedSummary = "\(layout.title) PDF prepared · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
            }
        }
    }

    private func exportDigital() {
        guard requireReady(), requireExportAccess(), !isExporting else { return }
        guard let photo = session.cgImage else { return }
        isExporting = true
        failure = nil
        preparedSummary = nil
        let revision = session.revision
        let spec = self.spec
        let unlimited = entitlements.isUnlocked

        exportTask = Task {
            let data = await Task.detached(priority: .userInitiated) {
                DigitalExport.jpegData(from: photo, spec: spec)
            }.value
            guard !Task.isCancelled, session.revision == revision,
                  session.canExport(for: spec),
                  unlimited || entitlements.exportCredits > 0 else {
                isExporting = false
                return
            }
            isExporting = false
            guard let data else {
                failure = "The digital file could not meet the output requirements. Try a less detailed crop or another original."
                return
            }
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            if stage(data, name: spec.id, fileExtension: "jpg") {
                entitlements.consumeExportCredit()
                preparedSummary = "\(spec.widthPixels) × \(spec.heightPixels) JPEG prepared · \(size)"
            }
        }
    }

    private func requireReady() -> Bool {
        if isReady { return true }
        failure = "Complete the photo check without failures before exporting."
        return false
    }

    private func requireExportAccess() -> Bool {
        if entitlements.canExport { return true }
        goToUnlock = true
        return false
    }

    @discardableResult
    private func stage(_ data: Data, name: String, fileExtension: String) -> Bool {
        guard share == nil else { return false }
        cleanStaging()
        do {
            let url = try ExportStaging.stage(data: data, name: name, fileExtension: fileExtension)
            stagedURL = url
            share = ShareItem(url: url)
            return true
        } catch {
            failure = "The file could not be prepared for sharing. Check available storage and try again."
            return false
        }
    }

    private func finishSharing(_ url: URL) {
        // Own the URL captured by this activity, not a later export's file.
        ExportStaging.remove(url)
        if stagedURL == url { stagedURL = nil }
        if share?.url == url { share = nil }
    }

    private func cleanStaging() {
        // Presenting the system activity sheet can make this view disappear.
        // Never remove its file until the activity completes or is dismissed.
        guard share == nil, let stagedURL else { return }
        ExportStaging.remove(stagedURL)
        self.stagedURL = nil
    }
}

private struct LayoutRow: View {
    let item: PrintSheetLayout
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(isSelected ? Theme.accent : Theme.ruleStrong)
                }
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(isSelected ? Theme.sageWash : Theme.paperRaised, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.accent : Theme.rule, lineWidth: isSelected ? 1.5 : 0.7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("layout.\(item.rawValue)")
    }
}

private struct ExportFact: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(.caption).foregroundStyle(Theme.inkSecondary)
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private enum PDFThumbnail {
    /// Renders the actual first page, including its margins and footer. The
    /// thumbnail never changes the exported PDF's MediaBox or crop geometry.
    static func image(from data: Data, width: CGFloat) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider), let page = document.page(at: 1) else { return nil }
        let bounds = page.getBoxRect(.mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = width / bounds.width
        let size = CGSize(width: width, height: bounds.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { output in
            UIColor.white.setFill()
            output.fill(CGRect(origin: .zero, size: size))
            let context = output.cgContext
            context.translateBy(x: 0, y: size.height)
            context.scaleBy(x: scale, y: -scale)
            context.translateBy(x: -bounds.minX, y: -bounds.minY)
            context.drawPDFPage(page)
        }
    }
}
