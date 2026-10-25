//
//  ExportView.swift
//  PassportProof
//
//  Output-specific export of the exact measured crop. Failed/incomplete checks
//  cannot be bypassed. Calibration remains free; paid outputs use StoreKit.
//

import SwiftUI
import UIKit

@MainActor
struct ExportView: View {
    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession
    @EnvironmentObject private var entitlements: EntitlementStore

    @State private var share: ShareItem?
    @State private var stagedURL: URL?
    @State private var failure: String?
    @State private var preparedSummary: String?
    @State private var isExporting = false
    @State private var goToUnlock = false

    private var layout: PrintSheetLayout { session.layout }
    private var isReady: Bool { session.canExport(for: spec) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenTitle(title: "Export", subtitle: spec.workflow.title)

                preview

                if !isReady {
                    readinessCard
                }

                if spec.supportsPrintSheet {
                    printContent
                } else {
                    digitalContent
                }

                if let failure {
                    Label(failure, systemImage: "exclamationmark.triangle.fill")
                        .typeStyle(Typography.bodySmall)
                        .foregroundStyle(Theme.signalFail)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Theme.Spacing.l)
                        .background(Theme.failWash, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, Theme.Spacing.margin)
                        .padding(.top, Theme.Spacing.m)
                }

                if !entitlements.isUnlocked {
                    lockedCard
                }

                privacyFooter
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $share) { item in
            ShareSheet(items: [item.url]) {
                cleanStaging()
            }
        }
        .navigationDestination(isPresented: $goToUnlock) {
            UnlockView()
        }
        .onDisappear { cleanStaging() }
    }

    private var preview: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.l) {
            if let image = session.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 88, height: 108)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel("Prepared photo used for export")
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Label("MEASURED CROP", systemImage: "checkmark.seal.fill")
                    .font(.caption2.weight(.bold))
                    .tracking(0.7)
                    .foregroundStyle(Theme.signalPass)
                Text(spec.displayName)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(spec.supportsPrintSheet
                     ? "\(Format.sizeMM(width: spec.widthMM, height: spec.heightMM)) · 300 DPI"
                     : "\(Format.sizePixels(width: spec.widthPixels, height: spec.heightPixels)) · JPEG · sRGB")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.l)
        .background(Theme.paperRaised)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
    }

    private var readinessCard: some View {
        Label("Return to Photo check and complete every visual confirmation without a failed rule before exporting.", systemImage: "lock.fill")
            .typeStyle(Typography.bodySmall)
            .foregroundStyle(Theme.signalFail)
            .fixedSize(horizontal: false, vertical: true)
            .padding(Theme.Spacing.l)
            .background(Theme.failWash, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)
    }

    // MARK: Printed photo

    private var printContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Theme.SectionHeader(title: "Print layout")
            VStack(spacing: Theme.Spacing.s) {
                ForEach(PrintSheetLayout.allCases) { item in
                    LayoutRow(item: item, isSelected: layout == item) {
                        session.layout = item
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Label("Before your first print", systemImage: "ruler")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Print the free calibration page at 100% and measure its reference square. Printer scaling is the one thing a PDF cannot control.")
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                SecondaryAction(title: "Share free calibration sheet", isEnabled: !isExporting) {
                    exportCalibration()
                }
            }
            .padding(Theme.Spacing.l)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.xl)

            PrimaryButton(title: isExporting ? "Rendering print sheet…" : "Export print sheet", isEnabled: isReady && !isExporting) {
                exportPrintSheet()
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.xl)

            outputSummary
        }
    }

    // MARK: Digital photo

    private var digitalContent: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Theme.SectionHeader(title: "Digital file")

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                ExportFact(icon: "photo", title: "Geometry", value: "\(spec.widthPixels) × \(spec.heightPixels) pixels")
                ExportFact(icon: "doc", title: "Format", value: "JPEG · sRGB · 300 DPI metadata")
                if let maximum = spec.maximumFileSizeBytes {
                    ExportFact(icon: "arrow.down.doc", title: "File size", value: "No more than \(maximum / 1_000) kB, checked after encoding")
                }
                ExportFact(icon: "crop", title: "Editing", value: "Your reviewed crop only; no filters or synthesis")
            }
            .padding(Theme.Spacing.l)
            .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)

            PrimaryButton(title: isExporting ? "Preparing digital file…" : "Export digital file", isEnabled: isReady && !isExporting) {
                exportDigital()
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.m)

            outputSummary
        }
    }

    private var outputSummary: some View {
        Group {
            if let preparedSummary {
                Label(preparedSummary, systemImage: "checkmark.circle.fill")
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.signalPass)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.margin)
                    .padding(.top, Theme.Spacing.m)
            }
        }
    }

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Label("One-time export unlock", systemImage: "lock.open")
                .font(.headline)
                .foregroundStyle(Theme.ink)
            Text("Your print or digital export requires the one-time purchase. Analysis and calibration are free; there is no subscription.")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            SecondaryAction(title: "View unlock") { goToUnlock = true }
        }
        .padding(Theme.Spacing.l)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
    }

    private var privacyFooter: some View {
        Label("Exports are created locally and staged only while the system share sheet is in use. The temporary file is deleted when sharing finishes.", systemImage: "lock.shield")
            .typeStyle(Typography.meta)
            .foregroundStyle(Theme.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.top, Theme.Spacing.xl)
    }

    // MARK: Actions

    private func exportCalibration() {
        guard !isExporting else { return }
        isExporting = true
        failure = nil
        let layout = self.layout
        Task {
            let data = await Task.detached(priority: .userInitiated) {
                PrintSheetRenderer.calibrationPDFData(layout: layout)
            }.value
            isExporting = false
            guard let data else {
                failure = "The calibration sheet could not be rendered. Try another layout."
                return
            }
            stage(data, name: "calibration-\(layout.rawValue)", fileExtension: "pdf")
        }
    }

    private func exportPrintSheet() {
        guard requireReady(), requireUnlock(), !isExporting else { return }
        guard let photo = session.cgImage else { return }
        isExporting = true
        failure = nil
        preparedSummary = nil
        let revision = session.revision
        let layout = self.layout
        let spec = self.spec

        Task {
            let data = await Task.detached(priority: .userInitiated) {
                PrintSheetRenderer.pdfData(photo: photo, layout: layout, spec: spec)
            }.value
            guard !Task.isCancelled, session.revision == revision else { return }
            isExporting = false
            guard let data else {
                failure = "The print sheet could not be rendered from this crop."
                return
            }
            preparedSummary = "\(layout.title) PDF ready · \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))"
            stage(data, name: "\(spec.id)-\(layout.rawValue)", fileExtension: "pdf")
        }
    }

    private func exportDigital() {
        guard requireReady(), requireUnlock(), !isExporting else { return }
        guard let photo = session.cgImage else { return }
        isExporting = true
        failure = nil
        preparedSummary = nil
        let revision = session.revision
        let spec = self.spec

        Task {
            let data = await Task.detached(priority: .userInitiated) {
                DigitalExport.jpegData(from: photo, spec: spec)
            }.value
            guard !Task.isCancelled, session.revision == revision else { return }
            isExporting = false
            guard let data else {
                failure = "The digital file could not meet the output requirements. Try a less detailed crop or another original."
                return
            }
            let size = ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
            preparedSummary = "\(spec.widthPixels) × \(spec.heightPixels) JPEG ready · \(size)"
            stage(data, name: spec.id, fileExtension: "jpg")
        }
    }

    private func requireReady() -> Bool {
        if isReady { return true }
        failure = "Complete the photo check without failures before exporting."
        return false
    }

    private func requireUnlock() -> Bool {
        if entitlements.isUnlocked { return true }
        goToUnlock = true
        return false
    }

    private func stage(_ data: Data, name: String, fileExtension: String) {
        cleanStaging()
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("passportproof-\(safeName)-\(UUID().uuidString)")
            .appendingPathExtension(fileExtension)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            stagedURL = url
            share = ShareItem(url: url)
        } catch {
            failure = "The file could not be prepared for sharing. Check available storage and try again."
        }
    }

    private func cleanStaging() {
        guard let stagedURL else { return }
        try? FileManager.default.removeItem(at: stagedURL)
        self.stagedURL = nil
    }
}

private struct LayoutRow: View {
    let item: PrintSheetLayout
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accent : Theme.inkTertiary)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                    Text(item.subtitle)
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.inkSecondary)
                }
                Spacer()
                Text("\(item.columns * item.rows)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.inkSecondary)
                    .accessibilityLabel("\(item.columns * item.rows) photos")
            }
            .padding(Theme.Spacing.l)
            .background(isSelected ? Theme.accent.opacity(0.09) : Theme.paperRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Theme.accent : Theme.rule, lineWidth: isSelected ? 1.5 : 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
