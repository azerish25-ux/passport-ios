//
//  PhotoReview.swift
//  PassportProof
//
//  Visual checks that software cannot settle honestly. These are explicit user
//  confirmations, never inferred from a classifier that does not exist.
//

import Foundation

struct PhotoReview: Equatable, Sendable {
    var expressionConfirmed = false
    var glassesConfirmed = false
    var originalUneditedConfirmed = false
    var recentPhotoConfirmed = false

    static let pending = PhotoReview()

    var allConfirmed: Bool {
        expressionConfirmed && glassesConfirmed && originalUneditedConfirmed && recentPhotoConfirmed
    }
}
