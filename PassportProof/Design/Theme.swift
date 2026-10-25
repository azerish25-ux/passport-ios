//
//  Theme.swift
//  PassportProof
//
//  The single source of truth for colour, type, space, stroke, and motion.
//  Precision-instrument direction: warm paper, warm ink, hairlines, no shadows,
//  no gradients, no rounded-card containers.
//
//  Every colour is resolved through a dynamic UIColor provider, so call sites
//  never branch on `colorScheme`.
//

import SwiftUI
import UIKit

// MARK: - Dynamic colour plumbing
//
// Deliberately file-private free functions rather than extensions on UIColor/Color,
// so a feature file may define its own `UIColor(hex:)` without creating an ambiguity.

private func hexUIColor(_ hex: UInt32, _ alpha: CGFloat = 1) -> UIColor {
    UIColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255.0,
        green: CGFloat((hex >> 8) & 0xFF) / 255.0,
        blue: CGFloat(hex & 0xFF) / 255.0,
        alpha: alpha
    )
}

/// A colour that resolves differently in light and dark appearance, with no
/// `colorScheme` branching at the call site.
private func adaptiveColor(
    light: UInt32,
    dark: UInt32,
    lightAlpha: CGFloat = 1,
    darkAlpha: CGFloat = 1
) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? hexUIColor(dark, darkAlpha)
            : hexUIColor(light, lightAlpha)
    })
}

// MARK: - Theme

enum Theme {

    // MARK: Surfaces

    /// Screen ground. Warm paper in light, warm near-black in dark. Never pure white or black.
    static let paper = adaptiveColor(light: 0xF4F1EA, dark: 0x17140E)

    /// Recessed areas: expanded row bodies, selected rows, wells.
    static let paperSunk = adaptiveColor(light: 0xEAE5D8, dark: 0x100E09)

    /// Slightly lifted surfaces: top bar, readout strip off-camera.
    static let paperRaised = adaptiveColor(light: 0xFBF9F4, dark: 0x201C14)

    // MARK: Ink

    static let ink = adaptiveColor(light: 0x14120F, dark: 0xEDE8DC)
    static let inkSecondary = adaptiveColor(light: 0x4C463A, dark: 0xA9A292)
    static let inkTertiary = adaptiveColor(light: 0x7B7364, dark: 0x7C7565)

    // MARK: Rules

    /// Hairline separator. Always drawn at `Stroke.hairline` (0.5pt).
    static let rule = adaptiveColor(light: 0xD8D2C4, dark: 0x332F26)

    /// Section rules and the measurement axis. Drawn at `Stroke.rule` (1pt).
    static let ruleStrong = adaptiveColor(light: 0xB4AC99, dark: 0x4C4638)

    // MARK: Accent — interaction only

    /// Marks position and primary interaction.
    static let accent = adaptiveColor(light: 0x0D6B60, dark: 0x63D3BD)
    static let onAccent = adaptiveColor(light: 0xFFFFFF, dark: 0x092821)

    /// Always-dark hero surfaces and their fixed foreground roles. These do not
    /// invert with the rest of the interface because the ground stays dark.
    static let heroTop = adaptiveColor(light: 0x183E3B, dark: 0x102C2A)
    static let heroBottom = adaptiveColor(light: 0x0C2529, dark: 0x081C1E)
    static let heroInk = Color(uiColor: hexUIColor(0xF7F4EC))
    static let heroMuted = Color(uiColor: hexUIColor(0xC4D1C9))
    static let captureInk = Color.white
    static let captureMuted = Color.white.opacity(0.76)

    // MARK: Signals — findings only

    /// FAIL.
    static let signalFail = adaptiveColor(light: 0xB23A1E, dark: 0xE0704F)

    /// PASS.
    static let signalPass = adaptiveColor(light: 0x2F6B4F, dark: 0x6FAE8C)

    /// CANNOT VERIFY.
    static let signalVerify = adaptiveColor(light: 0x82631B, dark: 0xC9A44E)

    /// Ground for a FAIL row.
    static let failWash = adaptiveColor(light: 0xF3E3DC, dark: 0x2A1712)

    /// Ground for a CANNOT VERIFY row.
    static let verifyWash = adaptiveColor(light: 0xEFE8D3, dark: 0x241E0E)

    /// Allowed-range band on the measurement bar. Never changes colour.
    static let bandFill = adaptiveColor(light: 0xDCD5C4, dark: 0x2E2A21)

    /// Pressed primary button fill.
    static let inkPressed = adaptiveColor(light: 0x2B2721, dark: 0xD6D0C2)

    // MARK: On-ink

    /// Text and marks placed on an `ink` fill.
    static let onInk = adaptiveColor(light: 0xF4F1EA, dark: 0x16140F)

    /// Secondary text and dividers on an `ink` fill.
    static let onInkMuted = adaptiveColor(light: 0xC6BFAE, dark: 0x4C4638)

    // MARK: Camera

    /// Flat, hard-edged scrim around the capture guide. No blur.
    static let scrim = adaptiveColor(light: 0x0B0A08, dark: 0x0B0A08, lightAlpha: 0.62, darkAlpha: 0.62)

    /// Head-height band fill inside the capture guide.
    static let captureBand = adaptiveColor(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.10)

    // MARK: - Spacing (4pt base)

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48

        /// Screen margin. Every full-bleed element respects this horizontally.
        static let margin: CGFloat = 20

        /// Gap between a value and its unit.
        static let unitGap: CGFloat = 3
    }

    // MARK: - Radius

    enum Radius {
        /// Rules, buttons, camera guides.
        static let none: CGFloat = 0

        /// The only container radius permitted.
        static let container: CGFloat = 2
    }

    // MARK: - Stroke

    enum Stroke {
        static let hairline: CGFloat = 0.5
        static let rule: CGFloat = 1
        static let emphasis: CGFloat = 2
        static let statusRail: CGFloat = 3
        static let cornerTick: CGFloat = 1.5
    }

    // MARK: - Component metrics

    enum Metrics {
        static let findingRowMinHeight: CGFloat = 64
        static let findingStatusColumn: CGFloat = 100
        static let findingPaddingVertical: CGFloat = 12

        static let measurementBarHeight: CGFloat = 34
        static let measurementBandHeight: CGFloat = 6
        static let measurementMarkerWidth: CGFloat = 2
        static let measurementMarkerHeight: CGFloat = 16
        static let measurementTickHeight: CGFloat = 4
        static let measurementTickCount: Int = 5

        static let documentRowHeight: CGFloat = 72
        static let documentCodeColumn: CGFloat = 56

        static let sectionHeaderHeight: CGFloat = 28
        static let sectionRuleOffset: CGFloat = 8

        static let buttonHeight: CGFloat = 52
        static let buttonBottomInset: CGFloat = 16
        static let tapTarget: CGFloat = 44

        static let captureGuideInset: CGFloat = 24
        static let captureGuideTop: CGFloat = 96
        static let captureCornerTickLength: CGFloat = 14
        static let captureReadoutHeight: CGFloat = 56
    }

    // MARK: - Motion

    enum Motion {
        /// The only animation in the app: finding rows settling in.
        static let settleDuration: Double = 0.22
        static let settleStagger: Double = 0.04
        static let settleMaxStaggeredRows: Int = 6
        static let settleOffset: CGFloat = 6

        /// No overshoot. Nothing bouncy.
        static let settle = Animation.timingCurve(0.2, 0, 0, 1, duration: settleDuration)

        /// Reduced-motion substitute: opacity only, shorter.
        static let settleReduced = Animation.linear(duration: 0.12)

        /// Pressed-state feedback on the primary button.
        static let press = Animation.linear(duration: 0.08)
    }
}

// MARK: - Typography

enum Typography {

    /// A complete type style: face, size, tracking, line spacing, case.
    struct Style {
        let font: Font
        let tracking: CGFloat
        /// Extra leading added on top of the font's natural line height.
        let lineSpacing: CGFloat
        let uppercased: Bool

        /// A `Text` carrying face, size, tracking, and case. Colour is applied by the caller.
        func text(_ string: String) -> Text {
            let resolved = uppercased ? string.uppercased() : string
            return Text(resolved).font(font).tracking(tracking)
        }
    }

    // MARK: Faces

    private static func text(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(textStyle(for: size), design: .default, weight: weight)
    }

    private static func mono(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(textStyle(for: size), design: .monospaced, weight: weight).monospacedDigit()
    }

    /// Numeric design tokens map to semantic text styles so every style scales
    /// with Dynamic Type instead of remaining fixed at a point size.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 32...: return .largeTitle
        case 27..<32: return .title
        case 22..<27: return .title2
        case 19..<22: return .title3
        case 16.5..<19: return .headline
        case 15.5..<16.5: return .body
        case 14.5..<15.5: return .callout
        case 13.5..<14.5: return .subheadline
        case 12.5..<13.5: return .footnote
        case 11.5..<12.5: return .caption
        default: return .caption2
        }
    }

    // MARK: Scale

    /// 34 / 40, Regular, −0.6. Screen titles only.
    static let display = Style(font: text(34, .regular), tracking: -0.6, lineSpacing: 0, uppercased: false)

    /// 24 / 28, Medium, −0.3.
    static let title = Style(font: text(24, .medium), tracking: -0.3, lineSpacing: 0, uppercased: false)

    /// 16 / 24, Regular.
    static let body = Style(font: text(16, .regular), tracking: 0, lineSpacing: 5, uppercased: false)

    /// 14 / 20, Regular.
    static let bodySmall = Style(font: text(14, .regular), tracking: 0, lineSpacing: 3, uppercased: false)

    /// 12 / 16, Regular, +0.1. Supporting prose, range descriptions.
    static let meta = Style(font: text(12, .regular), tracking: 0.1, lineSpacing: 2, uppercased: false)

    /// 11 / 14, Semibold, +1.6, uppercase. Section headers.
    static let sectionLabel = Style(font: text(11, .semibold), tracking: 1.6, lineSpacing: 1, uppercased: true)

    /// 10 / 12, Semibold, +1.4, uppercase. PASS / FAIL / CANNOT VERIFY.
    static let findingLabel = Style(font: mono(10, .semibold), tracking: 1.4, lineSpacing: 0, uppercased: true)

    /// 30 / 32, Medium, −0.6. The hero value. One per screen where possible.
    static let measurement = Style(font: mono(30, .medium), tracking: -0.6, lineSpacing: 0, uppercased: false)

    /// 17 / 20, Medium, −0.2. Values inside rows and readouts.
    static let measurementInline = Style(font: mono(17, .medium), tracking: -0.2, lineSpacing: 0, uppercased: false)

    /// 11 / 13, Regular, +0.8, uppercase. mm, °, dpi.
    static let unit = Style(font: mono(11, .regular), tracking: 0.8, lineSpacing: 0, uppercased: true)

    /// 12 / 16, Regular, +0.2. Sources, dates, document codes in running text.
    static let tabular = Style(font: mono(12, .regular), tracking: 0.2, lineSpacing: 2, uppercased: false)

    /// 13 / 18, Medium, +2.2, uppercase. Document codes and reference IDs.
    static let mrz = Style(font: mono(13, .medium), tracking: 2.2, lineSpacing: 2, uppercased: true)

    /// 14 / 18, Semibold, +1.1, uppercase. Buttons.
    static let button = Style(font: text(14, .semibold), tracking: 1.1, lineSpacing: 1, uppercased: true)

    // MARK: Composition

    /// A value with its unit on the same baseline: `Typography.value("31.4", unit: "mm")`.
    static func value(_ number: String, unit unitText: String) -> Text {
        measurement.text(number) + Text(" ") + Typography.unit.text(unitText)
    }

    /// An inline value with its unit: `Typography.inlineValue("31.4", unit: "mm")`.
    static func inlineValue(_ number: String, unit unitText: String) -> Text {
        measurementInline.text(number) + Text(" ") + Typography.unit.text(unitText)
    }
}

// MARK: - Type application

extension View {
    /// Applies a full type style to a multi-line block, including leading and case.
    /// Prefer `Style.text(_:)` for a single `Text` that needs to be concatenated.
    func typeStyle(_ style: Typography.Style) -> some View {
        self
            .font(style.font)
            .tracking(style.tracking)
            .lineSpacing(style.lineSpacing)
            .textCase(style.uppercased ? .uppercase : nil)
    }
}

// MARK: - Rules

extension Theme {

    /// A ruled line. Separation comes from this, never from a shadow.
    struct Rule: View {
        enum Orientation {
            case horizontal
            case vertical
        }

        var orientation: Orientation = .horizontal
        var color: Color = Theme.rule
        var weight: CGFloat = Theme.Stroke.hairline

        init(
            orientation: Orientation = .horizontal,
            color: Color = Theme.rule,
            weight: CGFloat = Theme.Stroke.hairline
        ) {
            self.orientation = orientation
            self.color = color
            self.weight = weight
        }

        var body: some View {
            switch orientation {
            case .horizontal:
                Rectangle()
                    .fill(color)
                    .frame(height: weight)
                    .frame(maxWidth: .infinity)
            case .vertical:
                Rectangle()
                    .fill(color)
                    .frame(width: weight)
                    .frame(maxHeight: .infinity)
            }
        }
    }

    /// Small-caps label, optional trailing datum, and a 1pt rule beneath. 28pt tall.
    struct SectionHeader: View {
        let title: String
        var trailing: String? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Metrics.sectionRuleOffset) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                    Typography.sectionLabel.text(title)
                        .foregroundStyle(Theme.inkSecondary)

                    Spacer(minLength: Theme.Spacing.m)

                    if let trailing {
                        Typography.tabular.text(trailing)
                            .foregroundStyle(Theme.inkTertiary)
                    }
                }

                Rule(color: Theme.ruleStrong, weight: Theme.Stroke.rule)
            }
            .padding(.top, Theme.Spacing.m)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
        }
    }
}
