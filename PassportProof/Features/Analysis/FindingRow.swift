//
//  FindingRow.swift
//  PassportProof
//
//  DesignSystem §4.1. Full-bleed, no card, separated by a 0.5pt rule that runs
//  edge to edge. Tappable across the full width; no chevron — expansion is shown
//  by the measurement bar appearing.
//
//  `cannotVerify` is a first-class state: dashed rail, its own colour, and its
//  reason in place of the required range.
//

import SwiftUI

struct FindingRow: View {

    let finding: Finding
    let verifiedOn: Date

    /// Settling animation, DesignSystem §5. The row is settled once the
    /// diagnosis has completed and the stagger has elapsed.
    var isSettled: Bool = true
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private var tint: Color { StatusInk.color(for: finding.status) }
    private var ground: Color { StatusInk.wash(for: finding.status) }

    private var settleDelay: Double {
        let staggerable = min(index, Theme.Motion.settleMaxStaggeredRows - 1)
        return Double(max(0, staggerable)) * Theme.Motion.settleStagger
    }

    private var settleAnimation: Animation {
        reduceMotion
            ? Theme.Motion.settleReduced
            : Theme.Motion.settle.delay(settleDelay)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            header

            if finding.status == .fail || finding.status == .cannotVerify {
                detailLine
            }

            sourceLine

            if isExpanded, let measurement = finding.measurement {
                MeasurementBar(measurement: measurement, status: finding.status)
                    .padding(.top, Theme.Spacing.l)
                    .padding(.horizontal, Theme.Spacing.margin)
            }
        }
        .padding(.leading, Theme.Stroke.statusRail + Theme.Spacing.margin)
        .padding(.trailing, Theme.Spacing.margin)
        .padding(.vertical, Theme.Metrics.findingPaddingVertical)
        .frame(minHeight: Theme.Metrics.findingRowMinHeight, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ground)
        .overlay(alignment: .leading) { rail }
        .contentShape(Rectangle())
        .onTapGesture { isExpanded.toggle() }
        .offset(y: isSettled ? 0 : Theme.Motion.settleOffset)
        .opacity(isSettled ? 1 : 0)
        .animation(settleAnimation, value: isSettled)
        .accessibilityElement(children: .combine)
        .accessibilityHint(finding.measurement == nil ? "" : "Shows the measurement bar")
    }

    // MARK: Rail

    /// 3pt wide, full row height, flush left. Dashed for `cannotVerify`, to say
    /// "unresolved" rather than "counted".
    @ViewBuilder
    private var rail: some View {
        if finding.status == .cannotVerify {
            GeometryReader { proxy in
                Path { path in
                    path.move(to: CGPoint(x: Theme.Stroke.statusRail / 2, y: 0))
                    path.addLine(to: CGPoint(x: Theme.Stroke.statusRail / 2, y: proxy.size.height))
                }
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: Theme.Stroke.statusRail, dash: [2, 2])
                )
            }
            .frame(width: Theme.Stroke.statusRail)
        } else {
            Rectangle()
                .fill(tint)
                .frame(width: Theme.Stroke.statusRail)
        }
    }

    // MARK: Lines

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {

            Typography.findingLabel.text(finding.status.uiLabel)
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(width: Theme.Metrics.findingStatusColumn, alignment: .leading)

            Text(finding.title)
                .typeStyle(Typography.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: Theme.Spacing.s)

            value
        }
    }

    private var value: some View {
        Group {
            if finding.status == .cannotVerify {
                Typography.measurementInline.text("—")
                    .foregroundStyle(Theme.inkTertiary)
            } else if let measurement = finding.measurement {
                Typography.measurementInline.text(measurement.displayValue)
                    .foregroundStyle(finding.status == .fail ? Theme.signalFail : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                Typography.measurementInline.text("—")
                    .foregroundStyle(Theme.inkTertiary)
            }
        }
    }

    @ViewBuilder
    private var detailLine: some View {
        if finding.status == .cannotVerify {
            Text(finding.detail)
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xxs)
        } else if let measurement = finding.measurement {
            Text("Required \(measurement.displayRange) · \(finding.detail)")
                .typeStyle(Typography.meta)
                .foregroundStyle(Theme.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xxs)
        }
    }

    private var sourceLine: some View {
        Text("\(finding.provenance.uiLabel) · verified \(Format.day(verifiedOn))")
            .typeStyle(Typography.tabular)
            .foregroundStyle(Theme.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Theme.Spacing.xxs)
    }
}
