//
//  Components.swift
//  PassportProof
//
//  The four shared pieces of the system: the primary button, the secondary
//  action, the screen title block, and the status colour map.
//  Everything else is built in place from Theme tokens.
//

import SwiftUI

// MARK: - Primary button

/// Width screen − 40, height 52, radius 0. One per screen.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? Theme.onInk : Theme.inkTertiary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.buttonHeight)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                fill(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }

    private func fill(isPressed: Bool) -> Color {
        guard isEnabled else { return Theme.rule }
        return isPressed ? Theme.inkPressed : Theme.ink
    }
}

/// High-emphasis action placed on a dark hero surface.
struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.buttonHeight)
            .background(
                Theme.accent.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(Theme.Motion.press, value: configuration.isPressed)
    }
}

/// Convenience wrapper for a primary action that is not a navigation link.
struct PrimaryButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
        }
        .buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
        .disabled(!isEnabled)
    }
}

// MARK: - Secondary action

/// `button` style, `ink`, no fill, no border, 44pt tap target, 1pt rule
/// underline 6pt below the baseline.
struct SecondaryAction: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEnabled ? Theme.accent : Theme.inkTertiary)
                .frame(minHeight: Theme.Metrics.tapTarget)
                .padding(.horizontal, Theme.Spacing.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Screen title

/// Display title plus an optional one-line datum beneath it.
struct ScreenTitle: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Typography.display.text(title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .typeStyle(Typography.bodySmall)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
    }
}

// MARK: - Status colour

/// Colour marks truth, never taste. These three are the only colours that ever
/// touch a finding, and each has exactly one meaning.
enum StatusInk {
    static func color(for status: FindingStatus) -> Color {
        switch status {
        case .pass:
            return Theme.signalPass
        case .fail:
            return Theme.signalFail
        case .cannotVerify:
            return Theme.signalVerify
        }
    }

    static func wash(for status: FindingStatus) -> Color {
        switch status {
        case .pass:
            return Theme.paper
        case .fail:
            return Theme.failWash
        case .cannotVerify:
            return Theme.verifyWash
        }
    }
}

// MARK: - Readout strip

/// Height 56, fill `ink`, three columns split by 1pt `onInkMuted` rules.
/// Values are `measurementInline` on `onInk`; captions are `unit` on `onInkMuted`.
struct ReadoutStrip: View {
    struct Column: Identifiable {
        let id: String
        let value: Text
        let caption: String
    }

    let columns: [Column]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.indices), id: \.self) { index in
                if index > 0 {
                    Theme.Rule(
                        orientation: .vertical,
                        color: Theme.onInkMuted,
                        weight: Theme.Stroke.rule
                    )
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    columns[index].value
                        .foregroundColor(Theme.onInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Typography.unit.text(columns[index].caption)
                        .foregroundStyle(Theme.onInkMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.m)
            }
        }
        .frame(height: Theme.Metrics.captureReadoutHeight)
        .background(Theme.ink)
    }
}
