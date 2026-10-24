//
//  Finding.swift
//  PassportProof
//
//  The vocabulary of a diagnosis. Every rule returns one of three states —
//  never a bare boolean — so that "I could not tell" stays visible.
//

import Foundation

// MARK: - Status

enum FindingStatus: String, Codable, Sendable, CaseIterable {
    case pass
    case fail
    case cannotVerify
}

// MARK: - Rule identity

/// Declaration order is the order the engine emits findings in, and therefore
/// the order the Diagnose screen lists them in. Do not reorder.
enum RuleID: String, Codable, Sendable, CaseIterable {
    case headHeight
    case headHeightShare
    case eyeLine
    case centring
    case backgroundUniformity
    case shadow
    case expression
    case glasses
    case resolution
    case photoAge
    case noManipulation
}

// MARK: - Provenance

/// Where a number came from. `prototypeDefault` means "we chose this because the
/// sources are silent", and the UI must say so out loud.
enum Provenance: String, Codable, Sendable {
    case source
    case derived
    case prototypeDefault
}

// MARK: - Measurement

struct Measurement: Sendable, Equatable {
    /// The measured value, expressed in `unit`.
    let value: Double
    /// "mm" | "%" | "px" | "months".
    let unit: String
    let lowerBound: Double?
    let upperBound: Double?
    /// e.g. "27.4 mm", "2.1%".
    let displayValue: String
    /// e.g. "25.4 – 34.9 mm". Uses an en dash, not a hyphen.
    let displayRange: String
}

// MARK: - Finding

struct Finding: Identifiable, Sendable {
    let id: RuleID
    let title: String
    let status: FindingStatus
    /// Why it failed, or why it could not be determined, and what to do next.
    let detail: String
    let measurement: Measurement?
    let provenance: Provenance
}
