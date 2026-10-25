//
//  Components.swift
//  PassportProof
//
//  Shared controls, studio surfaces and original vector document artwork.
//

import SwiftUI

// MARK: - Primary button

/// A comfortably sized, wrapping primary action.
struct PrimaryButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    @Environment(\.isEnabled) private var environmentEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled && environmentEnabled ? Theme.onInk : Theme.inkTertiary)
            .padding(.horizontal, Theme.Spacing.l)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.buttonHeight)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                fill(isPressed: configuration.isPressed),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.press, value: configuration.isPressed)
    }

    private func fill(isPressed: Bool) -> Color {
        guard isEnabled && environmentEnabled else { return Theme.rule }
        return isPressed ? Theme.inkPressed : Theme.ink
    }
}

/// High-emphasis action placed on a dark hero surface.
struct AccentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isEnabled ? Theme.onAccent : Theme.inkTertiary)
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.buttonHeight)
            .background(
                (isEnabled ? Theme.accent : Theme.rule).opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(reduceMotion ? nil : Theme.Motion.press, value: configuration.isPressed)
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

// MARK: - Studio components

/// A consistent, content-sized surface. It intentionally has no fixed height.
struct StudioCard<Content: View>: View {
    var padding: CGFloat
    let content: Content

    init(padding: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.paperRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.rule, lineWidth: 0.7)
            }
    }
}

struct StudioEyebrow: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.4)
            .foregroundStyle(Theme.accent)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Decorative three-frame mark, drawn for PassportProof rather than borrowed
/// from a system symbol. Its name is supplied by the adjacent wordmark.
struct StudioMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.ink)
            RoundedRectangle(cornerRadius: 3)
                .stroke(Theme.onInk.opacity(0.35), lineWidth: 1)
                .frame(width: 19, height: 25)
                .rotationEffect(.degrees(-10))
                .offset(x: -3, y: -1)
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.onInk)
                .frame(width: 19, height: 25)
                .rotationEffect(.degrees(8))
                .offset(x: 3, y: 1)
            Capsule().fill(Theme.ink).frame(width: 6, height: 8).offset(x: 3, y: -2)
            Capsule().fill(Theme.ink).frame(width: 11, height: 5).offset(x: 3, y: 5)
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }
}

/// One-based active step. At accessibility sizes, retain labels and let rows
/// grow instead of shrinking essential text into a narrow horizontal strip.
struct StudioStepProgress: View {
    let current: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let names = ["Capture", "Check", "Export"]

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    ForEach(0..<names.count, id: \.self) { step($0) }
                }
            } else {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(0..<names.count, id: \.self) { index in
                        step(index)
                        if index < names.count - 1 {
                            Capsule().fill(Theme.ruleStrong).frame(maxWidth: 24).frame(height: 1)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(min(max(current, 1), 3)) of 3: \(names[min(max(current - 1, 0), 2)])")
    }

    private func step(_ index: Int) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(index + 1 == current ? Theme.ink : Theme.sageWash)
                if index + 1 < current {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold)).foregroundStyle(Theme.accent)
                } else {
                    Text("\(index + 1)").font(.caption2.weight(.semibold))
                        .foregroundStyle(index + 1 == current ? Theme.onInk : Theme.inkSecondary)
                }
            }
            .frame(width: 24, height: 24)
            Text(names[index])
                .font(.caption.weight(index + 1 == current ? .semibold : .regular))
                .foregroundStyle(index + 1 == current ? Theme.ink : Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Original artwork, not a photographed person or an example of an approved
/// document photo. All coordinates scale with the available space.
struct StudioPortraitArt: View {
    enum Style: Equatable { case portrait, printSheet, digital }
    var style: Style = .portrait
    var compact: Bool = false

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let circle = CGRect(x: center.x - unit * 0.47, y: center.y - unit * 0.47, width: unit * 0.94, height: unit * 0.94)
            context.fill(Path(ellipseIn: circle), with: .color(Theme.sageWash))

            if style == .printSheet {
                let page = CGRect(x: center.x - unit * 0.34, y: center.y - unit * 0.43, width: unit * 0.68, height: unit * 0.86)
                context.fill(Path(roundedRect: page, cornerRadius: unit * 0.035), with: .color(Theme.illustrationPaper))
                context.stroke(Path(roundedRect: page, cornerRadius: unit * 0.035), with: .color(Theme.sageStrong), lineWidth: 1)
                for row in 0..<3 {
                    for column in 0..<2 {
                        let r = CGRect(x: page.minX + unit * 0.055 + CGFloat(column) * unit * 0.29, y: page.minY + unit * 0.06 + CGFloat(row) * unit * 0.255, width: unit * 0.255, height: unit * 0.235)
                        portrait(in: r, context: context)
                    }
                }
            } else {
                let width = unit * (compact ? 0.65 : 0.62)
                let r = CGRect(x: center.x - width / 2, y: center.y - unit * 0.38, width: width, height: unit * 0.72)
                let back = r.offsetBy(dx: -unit * 0.07, dy: -unit * 0.04)
                context.fill(Path(roundedRect: back, cornerRadius: unit * 0.04), with: .color(Theme.sageStrong))
                context.fill(Path(roundedRect: r, cornerRadius: unit * 0.04), with: .color(Theme.illustrationPaper))
                context.stroke(Path(roundedRect: r, cornerRadius: unit * 0.04), with: .color(Theme.illustrationInk.opacity(0.12)), lineWidth: 1)
                let photo = CGRect(x: r.minX + width * 0.09, y: r.minY + unit * 0.055, width: width * 0.82, height: unit * 0.52)
                portrait(in: photo, context: context)
                var base = Path()
                base.move(to: CGPoint(x: photo.minX, y: r.maxY - unit * 0.07))
                base.addLine(to: CGPoint(x: photo.minX + width * 0.32, y: r.maxY - unit * 0.07))
                context.stroke(base, with: .color(Theme.illustrationInk.opacity(0.4)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                if style == .digital {
                    let badge = CGRect(x: r.maxX - unit * 0.17, y: r.maxY - unit * 0.1, width: unit * 0.34, height: unit * 0.18)
                    context.fill(Path(roundedRect: badge, cornerRadius: unit * 0.04), with: .color(Theme.illustrationInk))
                    context.draw(Text("JPEG").font(.system(size: unit * 0.06, weight: .semibold, design: .monospaced)).foregroundColor(.white), at: CGPoint(x: badge.midX, y: badge.midY))
                } else if !compact {
                    var measure = Path()
                    let x = r.maxX + unit * 0.065
                    measure.move(to: CGPoint(x: x, y: photo.minY))
                    measure.addLine(to: CGPoint(x: x, y: photo.maxY))
                    measure.move(to: CGPoint(x: x - 4, y: photo.minY))
                    measure.addLine(to: CGPoint(x: x + 4, y: photo.minY))
                    measure.move(to: CGPoint(x: x - 4, y: photo.maxY))
                    measure.addLine(to: CGPoint(x: x + 4, y: photo.maxY))
                    context.stroke(measure, with: .color(Theme.accent.opacity(0.6)), lineWidth: 1)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func portrait(in rect: CGRect, context: GraphicsContext) {
        let w = rect.width
        let h = rect.height
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + w * x, y: rect.minY + h * y) }
        context.fill(Path(roundedRect: rect, cornerRadius: w * 0.025), with: .color(Color(red: 0.86, green: 0.9, blue: 0.83)))

        var shoulders = Path()
        shoulders.move(to: point(0.08, 1))
        shoulders.addCurve(to: point(0.4, 0.67), control1: point(0.1, 0.75), control2: point(0.28, 0.71))
        shoulders.addLine(to: point(0.6, 0.67))
        shoulders.addCurve(to: point(0.92, 1), control1: point(0.72, 0.71), control2: point(0.9, 0.75))
        shoulders.closeSubpath()
        context.fill(shoulders, with: .color(Theme.illustrationInk))
        context.fill(Path(roundedRect: CGRect(x: rect.minX + w * 0.43, y: rect.minY + h * 0.53, width: w * 0.14, height: h * 0.2), cornerRadius: w * 0.055), with: .color(Color(red: 0.7, green: 0.49, blue: 0.33)))
        context.fill(Path(ellipseIn: CGRect(x: rect.minX + w * 0.3, y: rect.minY + h * 0.17, width: w * 0.4, height: h * 0.43)), with: .color(Color(red: 0.78, green: 0.58, blue: 0.41)))

        var hair = Path()
        hair.move(to: point(0.3, 0.34))
        hair.addCurve(to: point(0.35, 0.12), control1: point(0.25, 0.21), control2: point(0.29, 0.13))
        hair.addCurve(to: point(0.68, 0.16), control1: point(0.45, 0.04), control2: point(0.64, 0.07))
        hair.addCurve(to: point(0.7, 0.35), control1: point(0.75, 0.23), control2: point(0.73, 0.29))
        hair.addLine(to: point(0.64, 0.26))
        hair.addCurve(to: point(0.36, 0.23), control1: point(0.53, 0.28), control2: point(0.45, 0.18))
        hair.closeSubpath()
        context.fill(hair, with: .color(Theme.illustrationInk))
        var details = Path()
        details.move(to: point(0.38, 0.36)); details.addLine(to: point(0.43, 0.36))
        details.move(to: point(0.57, 0.36)); details.addLine(to: point(0.62, 0.36))
        details.move(to: point(0.45, 0.49)); details.addQuadCurve(to: point(0.55, 0.49), control: point(0.5, 0.51))
        context.stroke(details, with: .color(Theme.illustrationInk), style: StrokeStyle(lineWidth: max(0.7, w * 0.014), lineCap: .round))
    }
}
