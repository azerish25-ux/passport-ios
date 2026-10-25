//
//  FindingRow.swift
//  PassportProof
//
//  A compact summary first; detail, provenance and the measurement axis appear
//  on demand. Status uses icon, text and colour—not colour alone.
//

import SwiftUI

struct FindingRow: View {
    let finding: Finding
    let verifiedOn: Date
    var isSettled = true
    var index = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    private var tint: Color { StatusInk.color(for: finding.status) }
    private var icon: String {
        switch finding.status {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "exclamationmark.circle.fill"
        case .cannotVerify: return "eye.circle.fill"
        }
    }

    var body: some View {
        Button {
            withAnimation(reduceMotion ? .none : .easeOut(duration: 0.18)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .top, spacing: Theme.Spacing.m) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tint)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                            Text(finding.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: Theme.Spacing.s)
                            if let measurement = finding.measurement, finding.status != .cannotVerify {
                                Text(measurement.displayValue)
                                    .typeStyle(Typography.measurementInline)
                                    .foregroundStyle(tint)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                            }
                        }

                        HStack(spacing: Theme.Spacing.xs) {
                            Text(finding.status.uiLabel.uppercased())
                                .font(.caption2.weight(.bold))
                                .tracking(0.7)
                                .foregroundStyle(tint)
                            if let measurement = finding.measurement {
                                Text("· Required \(measurement.displayRange)")
                                    .typeStyle(Typography.meta)
                                    .foregroundStyle(Theme.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkTertiary)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }

                if finding.status != .pass || isExpanded {
                    Text(finding.detail)
                        .typeStyle(Typography.bodySmall)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isExpanded {
                    if let measurement = finding.measurement {
                        MeasurementBar(measurement: measurement, status: finding.status)
                            .accessibilityHidden(true)
                    }
                    Text("\(finding.provenance.uiLabel) · verified \(Format.day(verifiedOn))")
                        .typeStyle(Typography.meta)
                        .foregroundStyle(Theme.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StatusInk.wash(for: finding.status))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(finding.status == .pass ? 0.12 : 0.28), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isSettled ? 1 : 0)
        .offset(y: !reduceMotion && !isSettled ? Theme.Motion.settleOffset : 0)
        .animation(
            reduceMotion ? .none : Theme.Motion.settle.delay(Double(min(index, 5)) * Theme.Motion.settleStagger),
            value: isSettled
        )
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Collapse details" : "Show measurement details and source")
        .accessibilityIdentifier("finding.\(finding.id.rawValue)")
    }
}
