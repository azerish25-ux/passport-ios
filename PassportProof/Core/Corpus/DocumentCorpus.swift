//
//  DocumentCorpus.swift
//  PassportProof
//
//  Three complete US workflows. No empty catalogue slots and no output that
//  contradicts the issuer's printed-versus-digital guidance.
//

import Foundation

enum DocumentCorpus {

    static let documents: [DocumentSpec] = [
        DocumentSpec(
            id: "us-passport",
            country: "United States",
            countryCode: "US",
            documentName: "Passport",
            workflow: .printedPhoto,
            widthMM: 50.8,
            heightMM: 50.8,
            widthPixels: 600,
            heightPixels: 600,
            headHeightMM: 25...35,
            headHeightShare: nil,
            eyeLineFromBottomMM: nil,
            maximumPhotoAgeMonths: 6,
            maximumFileSizeBytes: nil,
            backgroundDescription: "Plain white or off-white, without shadows, texture, objects or lines",
            expressionRequirement: "Eyes open, mouth closed, with a neutral expression or natural smile",
            glassesRequirement: "No eyeglasses unless a documented medical exception applies; eyes must remain fully visible",
            sourceURL: url("https://travel.state.gov/content/travel/en/passports/how-apply/photos.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-passport-2026-10-24",
                    date: verifiedDate,
                    note: "Printed-photo workflow verified against current issuer guidance: 2 × 2 inches, 25–35 mm head height, and a six-month recency limit."
                )
            ]
        ),

        DocumentSpec(
            id: "us-visa",
            country: "United States",
            countryCode: "US",
            documentName: "Visa",
            workflow: .digitalPhoto,
            widthMM: 50.8,
            heightMM: 50.8,
            widthPixels: 600,
            heightPixels: 600,
            headHeightMM: 25.4...34.9,
            headHeightShare: 0.50...0.69,
            eyeLineFromBottomMM: 28...35,
            maximumPhotoAgeMonths: 6,
            maximumFileSizeBytes: 240_000,
            backgroundDescription: "Plain white or off-white background",
            expressionRequirement: "Neutral expression with both eyes open",
            glassesRequirement: "No eyeglasses unless a documented medical exception applies; frames, glare and shadows must not obscure the eyes",
            sourceURL: url("https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/digital-image-requirements.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-visa-2026-10-24",
                    date: verifiedDate,
                    note: "Digital workflow verified: square JPEG in sRGB, 600–1200 pixels, no more than 240 kB, with composition and recency rules linked to the issuer's photo guidance."
                )
            ]
        ),

        DocumentSpec(
            id: "us-dv-lottery",
            country: "United States",
            countryCode: "US",
            documentName: "DV Lottery",
            workflow: .digitalPhoto,
            widthMM: 50.8,
            heightMM: 50.8,
            widthPixels: 600,
            heightPixels: 600,
            headHeightMM: 25.4...34.9,
            headHeightShare: 0.50...0.69,
            eyeLineFromBottomMM: 28...35,
            maximumPhotoAgeMonths: 6,
            maximumFileSizeBytes: 240_000,
            backgroundDescription: "Plain white or off-white background",
            expressionRequirement: "Neutral expression with both eyes open",
            glassesRequirement: "No eyeglasses unless a documented medical exception applies; frames, glare and shadows must not obscure the eyes",
            sourceURL: url("https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-dv-lottery-2026-10-24",
                    date: verifiedDate,
                    note: "DV digital workflow verified without a year-specific label: 600 × 600 pixel JPEG, square aspect ratio, 50–69% head height, and no more than 240 kB."
                )
            ]
        )
    ]

    static func document(id: String) -> DocumentSpec? {
        documents.first { $0.id == id }
    }

    private static let verifiedDate: Date = makeDate(year: 2026, month: 10, day: 24)

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private static func url(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }
}
