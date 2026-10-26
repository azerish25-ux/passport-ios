//
//  PassportProofApp.swift
//  PassportProof
//
//  Entry point. No analytics, account or application backend. A scene-level
//  privacy cover obscures the interface when the app moves to the background.
//

import SwiftUI
import UIKit

@main
@MainActor
struct PassportProofApp: App {
    @StateObject private var entitlements = EntitlementStore()
    @StateObject private var session = PhotoSession()

    private var isLargeTextUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestLargeText")
    }

    init() {
        // Remove leftovers from a prior process; current active shares are kept.
        _ = ExportStaging.cleanupAbandonedFiles()
        PrivacyShieldCoordinator.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            appRoot
                .environmentObject(entitlements)
                .environmentObject(session)
                .task {
                    seedUITestPhotoIfRequested()
                    await entitlements.refresh()
                }
        }
    }

    /// Deterministic UI-test input. A system photo picker and a simulator's
    /// Vision behaviour are both outside this app's control, so a UI suite that
    /// depends on either tests Apple, not PassportProof. This seeds a synthetic
    /// original into the session so the crop, manual framing, review and export
    /// contracts can be asserted repeatably. DEBUG only; absent from Release.
    private func seedUITestPhotoIfRequested() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-UITestSeedPhoto"),
              arguments.index(after: flag) < arguments.endIndex,
              let spec = DocumentCorpus.document(id: arguments[arguments.index(after: flag)]),
              !session.hasPhoto else { return }
        guard let image = Self.syntheticPortrait(size: CGSize(width: 1200, height: 1200)) else { return }
        session.adopt(image, captureDate: Date(), for: spec)
        #endif
    }

    #if DEBUG
    /// A plain, high-contrast head-and-shoulders drawing. It deliberately
    /// contains no real person, so automatic face detection has nothing to
    /// claim and the manual-framing path is exercised honestly.
    private static func syntheticPortrait(size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let width = size.width
            let height = size.height
            UIColor(white: 0.28, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(
                x: width * 0.30, y: height * 0.14,
                width: width * 0.40, height: height * 0.46
            ))
            let shoulders = UIBezierPath(
                roundedRect: CGRect(x: width * 0.12, y: height * 0.62,
                                    width: width * 0.76, height: height * 0.56),
                cornerRadius: width * 0.16
            )
            shoulders.fill()
        }
    }
    #endif

    @ViewBuilder
    private var appRoot: some View {
        if isLargeTextUITest {
            RootView().dynamicTypeSize(.accessibility3)
        } else {
            RootView()
                .preferredColorScheme(isDarkUITest ? .dark : nil)
        }
    }

    private var isDarkUITest: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-UITestDarkMode")
        #else
        return false
        #endif
    }
}
