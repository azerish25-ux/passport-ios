import SwiftUI
import UIKit

/// A transactional, explicitly manual alternative to unavailable face geometry.
/// The accepted pixels never change here. Draft positions become session data
/// only after an explicit, revision-bound confirmation succeeds.
@MainActor
struct ManualFramingView: View {
    let image: UIImage
    let spec: DocumentSpec
    let revision: UUID
    let onConfirm: (ManualFramingGuides, ManualFramingReview, UUID) -> Bool
    let onCancel: () -> Void
    private let startsWithSavedGuides: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var guides: ManualFramingGuides
    @State private var review: ManualFramingReview
    @State private var activeGuide: ManualGuide = .top
    @State private var saveRejected = false

    init(image: UIImage, spec: DocumentSpec, revision: UUID,
         existing: ManualFramingRecord? = nil,
         onConfirm: @escaping (ManualFramingGuides, ManualFramingReview, UUID) -> Bool,
         onCancel: @escaping () -> Void) {
        self.image = image
        self.spec = spec
        self.revision = revision
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        let current: ManualFramingRecord? = existing.flatMap { record in
            record.documentID == spec.id && record.revision == revision
                && ManualFramingAssessment(guides: record.guides, spec: spec).isValid ? record : nil
        }
        startsWithSavedGuides = current != nil
        _guides = State(initialValue: current?.guides ?? .suggested(for: spec))
        _review = State(initialValue: current?.review ?? .pending)
    }

    private var assessment: ManualFramingAssessment {
        ManualFramingAssessment(guides: guides, spec: spec)
    }
    private var confirmedCount: Int {
        [review.guidesConfirmed, review.singleFaceAndPoseConfirmed,
         review.backgroundAndLightingConfirmed, review.limitationsAccepted].filter { $0 }.count
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 0) {
                    preview(height: min(dynamicTypeSize.isAccessibilitySize ? 180 : 280,
                                        max(120, proxy.size.height * (dynamicTypeSize.isAccessibilitySize ? 0.27 : 0.38))))
                    Theme.Rule()
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Place the guides yourself.")
                                    .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
                                Text("Align every guide with the actual feature in your photo. If the ranges do not fit, cancel and adjust the crop. Moving a guide away from the feature does not fix the photo.")
                                    .font(.subheadline).foregroundStyle(Theme.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(startsWithSavedGuides
                                     ? "This editor starts with your saved manual guides. Changes need a new confirmation."
                                     : "Starting positions are suggestions. They were not detected from your photo.")
                                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            guideControls
                            measurements
                            confirmations
                        }
                        .frame(maxWidth: 640)
                        .padding(.horizontal, Theme.Spacing.margin)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .background(Theme.paper)
            .navigationTitle("Manual framing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("manual.cancel")
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
        }
        .tint(Theme.accent)
    }

    private func preview(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Automatic measurements unavailable", systemImage: "exclamationmark.circle")
                .font(.caption.weight(.medium)).foregroundStyle(Theme.signalVerify)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("manual.automaticUnavailable")
            GeometryReader { proxy in
                let ratio = max(image.size.width, 1) / max(image.size.height, 1)
                let width = min(proxy.size.width, proxy.size.height * ratio)
                let imageHeight = width / ratio
                Image(uiImage: image)
                    .resizable().interpolation(.high)
                    .frame(width: width, height: imageHeight)
                    .overlay { ManualGuideOverlay(guides: guides, active: activeGuide) }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .accessibilityLabel("Your exact photo with guides positioned by you. Adjust the labeled sliders below.")
                    .accessibilityIdentifier("manual.preview")
            }
            .frame(height: height)
            HStack(spacing: 8) {
                Text("\(activeGuide.number)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.onInk)
                    .frame(width: 22, height: 22)
                    .background(Theme.ink, in: Circle())
                Text(activeGuide.title(for: spec))
                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                Text("Manual guide")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
            }
            .accessibilityHidden(true)
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, 10).padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.paperRaised)
    }

    private var guideControls: some View {
        StudioCard(padding: 16) {
            VStack(spacing: 14) {
                ForEach(ManualGuide.allCases) { guide in
                    if guide != .top { Theme.Rule() }
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text("\(guide.number). \(guide.title(for: spec))")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Text("\(number(value(for: guide) * 100))%")
                                .font(.caption.monospacedDigit()).foregroundStyle(Theme.inkSecondary)
                                .fixedSize()
                        }
                        Text(guide.instruction(for: spec))
                            .font(.footnote).foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Slider(value: binding(for: guide), in: 0...1, step: 0.001)
                            .tint(Theme.accent)
                            .frame(minHeight: 44)
                            .accessibilityLabel(guide.title(for: spec))
                            .accessibilityValue("\(number(value(for: guide) * 100)) percent from the \(guide == .center ? "left" : "top")")
                            .accessibilityHint(guide.instruction(for: spec))
                            .accessibilityIdentifier(guide.identifier)
                    }
                }
            }
        }
    }

    private var measurements: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudioEyebrow(title: "From your guides")
            Text("Your framing estimates")
                .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            Text("These numbers depend on where you placed the guides. They are not automatic measurements.")
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            StudioCard(padding: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    if let range = spec.headHeightShare {
                        metric("Head height", value: "\(number(assessment.headHeightShare * 100))%",
                               requirement: "Required: \(number(range.lowerBound * 100))–\(number(range.upperBound * 100))% of photo height")
                    } else {
                        metric("Head height", value: "\(number(assessment.headHeightMM)) mm",
                               requirement: "Required: \(number(spec.headHeightMM.lowerBound))–\(number(spec.headHeightMM.upperBound)) mm")
                    }
                    if let range = spec.eyeLineFromBottomMM {
                        Theme.Rule()
                        metric("Eye height from bottom", value: "\(number(assessment.eyeLineFromBottomMM / spec.heightMM * 100))%",
                               requirement: "Required: \(number(range.lowerBound / spec.heightMM * 100))–\(number(range.upperBound / spec.heightMM * 100))% of photo height")
                    }
                    Theme.Rule()
                    metric("Distance from center", value: "\(number(assessment.horizontalOffsetMM)) mm",
                           requirement: "App guide: within \(number(ValidationEngine.centringToleranceMM)) mm of center")
                }
            }
            .accessibilityIdentifier("manual.assessment")
            if assessment.isValid {
                Label("Guide positions fit these ranges. Confirm their placement below.", systemImage: "ruler")
                    .font(.footnote).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(assessment.issues.joined(separator: "\n\n"))
                    .font(.footnote).foregroundStyle(Theme.signalFail)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.failWash, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("manual.issues")
            }
        }
    }

    private func metric(_ title: String, value: String, requirement: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Theme.inkSecondary)
            Text(value).font(.title3.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.ink)
            Text(requirement).font(.footnote).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var confirmations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review your placement")
                .font(.title3.weight(.semibold)).foregroundStyle(Theme.ink)
            Text("\(confirmedCount) of 4 confirmed. Changing a guide resets these confirmations.")
                .font(.footnote).foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            StudioCard(padding: 4) {
                VStack(spacing: 0) {
                    manualConfirmation("I placed every guide", detail: "The guides match the head, chin, eyes and center of this photo. Suggested starting positions alone are not a review.",
                                       isOn: $review.guidesConfirmed, identifier: "manual.review.guides")
                    Theme.Rule().padding(.horizontal, 12)
                    manualConfirmation("One face, looking straight ahead", detail: "One person is visible, with the full head and face shown, eyes open and head level.",
                                       isOn: $review.singleFaceAndPoseConfirmed, identifier: "manual.review.face")
                    Theme.Rule().padding(.horizontal, 12)
                    manualConfirmation("I checked the background and light", detail: "The background is plain white or off-white. Lighting is even, with no shadows on the face or background.",
                                       isOn: $review.backgroundAndLightingConfirmed, identifier: "manual.review.background")
                    Theme.Rule().padding(.horizontal, 12)
                    manualConfirmation("I understand the limits", detail: "Manual guides do not verify this photo. Export formats it; the issuing authority decides whether to accept it.",
                                       isOn: $review.limitationsAccepted, identifier: "manual.review.limitations")
                }
            }
        }
    }

    private func manualConfirmation(_ title: String, detail: String,
                                    isOn: Binding<Bool>, identifier: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(detail).font(.footnote).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14).frame(minHeight: 64)
        .accessibilityIdentifier(identifier)
    }

    private var saveBar: some View {
        VStack(spacing: 8) {
            if saveRejected {
                Text("This photo or its checks have changed. Close this editor and review the current crop before saving guides.")
                    .font(.caption).foregroundStyle(Theme.signalFail)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("manual.saveError")
            } else if !assessment.isValid || !review.allConfirmed {
                Text(assessment.isValid ? "Confirm all four statements to continue." : "Adjust the guide positions to continue.")
                    .font(.caption).foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PrimaryButton(title: "Use manual framing", isEnabled: assessment.isValid && review.allConfirmed) {
                guard assessment.isValid, review.allConfirmed else { return }
                saveRejected = !onConfirm(guides, review, revision)
            }
            .accessibilityIdentifier("manual.confirm")
        }
        .frame(maxWidth: 640)
        .padding(.horizontal, Theme.Spacing.margin).padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Theme.paperRaised)
        .overlay(alignment: .top) { Theme.Rule() }
    }

    private func value(for guide: ManualGuide) -> Double {
        switch guide {
        case .top: return guides.topY
        case .chin: return guides.chinY
        case .eyes: return guides.eyeY
        case .center: return guides.centerX
        }
    }
    private func binding(for guide: ManualGuide) -> Binding<Double> {
        Binding(get: { value(for: guide) }, set: { value in
            guard value.isFinite, value != self.value(for: guide) else { return }
            switch guide {
            case .top: guides.topY = value
            case .chin: guides.chinY = value
            case .eyes: guides.eyeY = value
            case .center: guides.centerX = value
            }
            activeGuide = guide
            review = .pending
            saveRejected = false
        })
    }
    private func number(_ value: Double) -> String {
        value.isFinite ? String(format: "%.1f", value) : "—"
    }
}

private enum ManualGuide: String, CaseIterable, Identifiable {
    case top, chin, eyes, center
    var id: Self { self }
    var identifier: String { "manual.\(rawValue)" }
    var number: Int {
        switch self { case .top: return 1; case .chin: return 2; case .eyes: return 3; case .center: return 4 }
    }
    var color: Color {
        switch self {
        case .top: return Color(red: 0.25, green: 0.87, blue: 0.96)
        case .chin: return Color(red: 1, green: 0.72, blue: 0.30)
        case .eyes: return Color(red: 0.90, green: 0.64, blue: 1)
        case .center: return .white
        }
    }
    func title(for spec: DocumentSpec) -> String {
        switch self {
        case .top: return spec.headMeasurement == .skull ? "Head top, excluding hair" : "Head top, including hair"
        case .chin: return "Bottom of chin"
        case .eyes: return "Eye line"
        case .center: return "Face center"
        }
    }
    func instruction(for spec: DocumentSpec) -> String {
        switch self {
        case .top:
            return spec.headMeasurement == .skull
                ? "Estimate the top of the skull underneath the hair. Do not include hair volume."
                : "Place at the top of the head, including hair."
        case .chin: return "Place at the bottom of the chin, excluding any beard extending below it."
        case .eyes:
            return spec.eyeLineFromBottomMM == nil
                ? "Align with the middle of both eyes. This is a placement reference; this workflow has no published eye-height band."
                : "Align with the middle of both eyes. Check that your head is level."
        case .center: return "Align the vertical guide with the middle of your face."
        }
    }
}

/// Drawn over the exact image bounds, never over the containing letterbox.
/// Numbered marks remain distinguishable without relying on color alone.
private struct ManualGuideOverlay: View {
    let guides: ManualFramingGuides
    let active: ManualGuide

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(ManualGuide.allCases) { guide in
                    let value = position(for: guide)
                    let path = Path { path in
                        if guide == .center {
                            path.move(to: CGPoint(x: proxy.size.width * value, y: 0))
                            path.addLine(to: CGPoint(x: proxy.size.width * value, y: proxy.size.height))
                        } else {
                            path.move(to: CGPoint(x: 0, y: proxy.size.height * value))
                            path.addLine(to: CGPoint(x: proxy.size.width, y: proxy.size.height * value))
                        }
                    }
                    path.stroke(.black.opacity(0.65), lineWidth: guide == active ? 5 : 3)
                    path.stroke(guide.color, style: StrokeStyle(lineWidth: guide == active ? 2.5 : 1.5,
                                                               dash: guide == .center ? [5, 4] : []))
                    Text("\(guide.number)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(guide.color)
                        .frame(width: 22, height: 22)
                        .background(.black.opacity(0.85), in: Circle())
                        .overlay { Circle().stroke(guide.color, lineWidth: guide == active ? 2 : 1) }
                        .position(x: guide == .center ? bounded(proxy.size.width * value, in: proxy.size.width) : 14,
                                  y: guide == .center ? 14 : bounded(proxy.size.height * value, in: proxy.size.height))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func position(for guide: ManualGuide) -> CGFloat {
        let value: Double
        switch guide {
        case .top: value = guides.topY
        case .chin: value = guides.chinY
        case .eyes: value = guides.eyeY
        case .center: value = guides.centerX
        }
        return value.isFinite ? CGFloat(value) : 0
    }
    private func bounded(_ value: CGFloat, in dimension: CGFloat) -> CGFloat {
        min(max(value, 12), max(12, dimension - 12))
    }
}
