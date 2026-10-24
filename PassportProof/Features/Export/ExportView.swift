//
//  ExportView.swift
//  PassportProof
//
//  AC14 first: the calibration sheet is offered before anything is paid for and
//  is shared without consulting the entitlement store at all. The two exports
//  that follow are gated, and route to Unlock rather than showing a disabled
//  button with no explanation.
//
//  Files are staged in the temporary directory, shared, and deleted on sheet
//  dismissal. That is a share staging file, not photo storage: P1 forbids
//  persisting the user's photograph, and nothing here outlives the share.
//

import SwiftUI
import UIKit

@MainActor
struct ExportView: View {

    let spec: DocumentSpec

    @EnvironmentObject private var session: PhotoSession
    @EnvironmentObject private var entitlements: EntitlementStore

    @State private var share: ShareItem?
    @State private var failure: String?
    @State private var goToUnlock = false

    private var layout: PrintSheetLayout { session.layout }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                ScreenTitle(title: "Export", subtitle: spec.displayName)

                Theme.SectionHeader(
                    title: "Layout",
                    trailing: "\(layout.columns) × \(layout.rows)"
                )

                ForEach(PrintSheetLayout.allCases) { item in
                    LayoutRow(
                        item: item,
                        isSelected: layout == item
                    ) {
                        session.layout = item
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }

                    Theme.Rule()
                }

                Theme.SectionHeader(title: "Sheet")
                calibrationSection
                Theme.Rule()
                printSection
                Theme.Rule()
                digitalSection

                if let failure {
                    Text(failure)
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.signalFail)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Theme.Spacing.margin)
                        .padding(.top, Theme.Spacing.m)
                }

                if !entitlements.isUnlocked {
                    lockedNote
                }

                Text("Every sheet carries the instruction “print at 100% — do not scale”. A PDF carries a page box; the print driver decides whether to honour it, which is why the calibration sheet exists.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Theme.Spacing.margin)
                    .padding(.top, Theme.Spacing.xl)
                    .padding(.bottom, Theme.Spacing.xxxl)
            }
        }
        .background(Theme.paper)
        .navigationTitle(spec.documentName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $share) { item in
            ShareSheet(items: [item.url])
        }
        .navigationDestination(isPresented: $goToUnlock) {
            UnlockView()
        }
        .onDisappear {
            cleanStaging()
        }
    }

    // MARK: Calibration — never gated

    private var calibrationSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {

            Text("One page at this layout's exact page size. Print it at 100%, measure the marks against a ruler, and only then decide. Printing it does not use the unlock.")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryAction(title: "Print calibration sheet") {
                exportCalibration()
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: Print sheet — gated

    private var printSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {

            Typography.unit.text("print sheet")
                .foregroundStyle(Theme.inkTertiary)

            Text("\(Format.pageInches(layout.pageSizePoints)) · \(layout.columns) × \(layout.rows) cells · \(layout.supportsCutMarks ? "cut marks in a real gutter" : "no gutters — borderless only")")
                .typeStyle(Typography.tabular)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(
                title: "Export print sheet",
                isEnabled: session.hasPhoto
            ) {
                exportPrintSheet()
            }
            .padding(.top, Theme.Spacing.s)

            if !session.hasPhoto {
                Text("No photograph in this session. Capture one first.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: Digital file — gated

    private var digitalSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {

            Typography.unit.text("digital file")
                .foregroundStyle(Theme.inkTertiary)

            Text("JPEG · sRGB · quality 0.95 · \(Format.sizePixels(width: spec.widthPixels, height: spec.heightPixels)) · 300 dpi in metadata")
                .typeStyle(Typography.tabular)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SecondaryAction(title: "Export digital file", isEnabled: session.hasPhoto) {
                exportDigital()
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.m)
        .padding(.bottom, Theme.Spacing.l)
    }

    // MARK: Lock

    private var lockedNote: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Theme.accent)
                .frame(width: Theme.Stroke.emphasis)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("Locked")
                    .typeStyle(Typography.sectionLabel)
                    .foregroundStyle(Theme.inkSecondary)

                Text("The print sheet and the digital file need the one-time unlock. The calibration sheet above does not.")
                    .typeStyle(Typography.meta)
                    .foregroundStyle(Theme.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                SecondaryAction(title: "Unlock") {
                    goToUnlock = true
                }
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.vertical, Theme.Spacing.m)
        }
        .background(Theme.paperSunk)
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.l)
    }

    // MARK: Actions

    private func exportCalibration() {
        // Deliberately no entitlement check. AC14.
        guard let data = PrintSheetRenderer.calibrationPDFData(layout: layout) else {
            failure = "The calibration sheet could not be rendered."
            return
        }

        stage(data, name: "passportproof-calibration-\(layout.rawValue).pdf")
    }

    private func exportPrintSheet() {
        guard requireUnlock() else { return }

        guard let photo = session.cgImage else {
            failure = "No photograph in this session."
            return
        }

        guard let data = PrintSheetRenderer.pdfData(photo: photo, layout: layout, spec: spec) else {
            failure = "The print sheet could not be rendered."
            return
        }

        stage(data, name: "passportproof-\(spec.id)-\(layout.rawValue).pdf")
    }

    private func exportDigital() {
        guard requireUnlock() else { return }

        guard let photo = session.cgImage else {
            failure = "No photograph in this session."
            return
        }

        guard let data = DigitalExport.jpegData(from: photo, spec: spec) else {
            failure = "The digital file could not be rendered."
            return
        }

        stage(data, name: "passportproof-\(spec.id).jpg")
    }

    private func requireUnlock() -> Bool {
        if entitlements.isUnlocked { return true }
        goToUnlock = true
        return false
    }

    // MARK: Staging

    private func stage(_ data: Data, name: String) {
        failure = nil

        // Clear the previous share before writing the next one, so staging
        // files never accumulate. The photo itself is never written to disk.
        cleanStaging()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)

        do {
            try data.write(to: url, options: .atomic)
            share = ShareItem(url: url)
        } catch {
            failure = "The file could not be written to the share folder."
        }
    }

    /// Removes every staging file this screen wrote. Runs on sheet dismissal and
    /// on leaving the screen, so a shared file does not outlive its use.
    private func cleanStaging() {
        let directory = FileManager.default.temporaryDirectory

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }

        for url in contents where url.lastPathComponent.hasPrefix("passportproof-") {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - Layout row

private struct LayoutRow: View {
    let item: PrintSheetLayout
    let isSelected: Bool
    let onSelect: () -> Void

    private var detail: String {
        let cells = "\(item.columns) × \(item.rows) cells"
        let page = Format.pageInches(item.pageSizePoints)
        let gutter = item.supportsCutMarks ? "cut marks" : "no gutters"
        return "\(cells) · \(page) · \(gutter)"
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(item.title)
                        .typeStyle(Typography.body)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.subtitle)
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(detail)
                        .typeStyle(Typography.tabular)
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Theme.Spacing.s)

                if isSelected {
                    Typography.findingLabel.text("Selected")
                        .foregroundStyle(Theme.accent)
                        .padding(.top, Theme.Spacing.xxs)
                }
            }
            .padding(.horizontal, Theme.Spacing.margin)
            .padding(.vertical, Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Theme.paperSunk : Theme.paper)
            .overlay(alignment: .leading) {
                if isSelected {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: Theme.Stroke.emphasis)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
