//
//  AppRoute.swift
//  PassportProof
//
//  The whole navigation surface. A route carries a document id, never a
//  DocumentSpec — DocumentSpec is not Hashable in the contract, and a route
//  holding an image would be both unhashable and a persistence hazard.
//

import Foundation

enum AppRoute: Hashable {
    /// The rules, provenance, and changelog for one encoded document.
    case documentDetail(documentID: String)
    /// Camera or library import, gated by `CaptureGate`.
    case capture(documentID: String)
    /// Findings for the photo currently held in `PhotoSession`.
    case analysis(documentID: String)
    /// Print sheet and digital file.
    case export(documentID: String)
    /// One price, one button.
    case unlock
}
