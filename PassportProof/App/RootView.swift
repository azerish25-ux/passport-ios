//
//  RootView.swift
//  PassportProof
//
//  One NavigationStack over AppRoute. No tab bar (BUILD-CONTRACT §4).
//  Cold launch lands on the Library, so AC1 is satisfied without a sign-in
//  wall and without asking for the camera until the user reaches Capture.
//

import SwiftUI

@MainActor
struct RootView: View {

    var body: some View {
        NavigationStack {
            DocumentLibraryView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .tint(Theme.ink)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {

        case .documentDetail(let documentID):
            if let spec = DocumentCorpus.document(id: documentID) {
                DocumentDetailView(spec: spec)
            } else {
                MissingDocumentView(documentID: documentID)
            }

        case .capture(let documentID):
            if let spec = DocumentCorpus.document(id: documentID) {
                CaptureView(spec: spec)
            } else {
                MissingDocumentView(documentID: documentID)
            }

        case .analysis(let documentID):
            if let spec = DocumentCorpus.document(id: documentID) {
                AnalysisView(spec: spec)
            } else {
                MissingDocumentView(documentID: documentID)
            }

        case .export(let documentID):
            if let spec = DocumentCorpus.document(id: documentID) {
                ExportView(spec: spec)
            } else {
                MissingDocumentView(documentID: documentID)
            }

        case .unlock:
            UnlockView()
        }
    }
}

/// Reached only if a route names a document the corpus does not hold. This is
/// the visible form of risk 7: a missing document is stated, never approximated.
struct MissingDocumentView: View {
    let documentID: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Typography.sectionLabel.text("Not encoded")
                .foregroundStyle(Theme.inkSecondary)

            Typography.title.text("This document is not in the corpus")
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("No rules are encoded for “\(documentID)”. Nothing is inferred for a document that is not listed. The counter at the intake desk remains the reference.")
                .typeStyle(Typography.bodySmall)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.margin)
        .padding(.top, Theme.Spacing.xl)
        .background(Theme.paper)
        .navigationBarTitleDisplayMode(.inline)
    }
}
