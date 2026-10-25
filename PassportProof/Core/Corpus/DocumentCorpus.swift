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
            headMeasurement: .skull,
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
                    id: "us-passport-2026-10-25",
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
            headHeightMM: digitalHeadHeightRange,
            headMeasurement: .includingHair,
            headHeightShare: 0.50...0.69,
            eyeLineFromBottomMM: digitalEyeLineRange,
            maximumPhotoAgeMonths: 6,
            maximumFileSizeBytes: 240_000,
            backgroundDescription: "Plain white or off-white background",
            expressionRequirement: "Neutral expression with both eyes open",
            glassesRequirement: "No eyeglasses unless a documented medical exception applies; frames, glare and shadows must not obscure the eyes",
            sourceURL: url("https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/digital-image-requirements.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-visa-2026-10-25",
                    date: verifiedDate,
                    note: "Digital workflow: square JPEG in sRGB, 600–1200 pixels and no more than 240 kB. Composition uses the top of hair to chin at 50–69% and eye line at 56–69% from the bottom; displayed millimetres are derived from those fractions, not rounded paper-photo limits."
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
            headHeightMM: digitalHeadHeightRange,
            headMeasurement: .includingHair,
            headHeightShare: 0.50...0.69,
            eyeLineFromBottomMM: digitalEyeLineRange,
            maximumPhotoAgeMonths: 6,
            maximumFileSizeBytes: 240_000,
            backgroundDescription: "Plain white or off-white background",
            expressionRequirement: "Neutral expression with both eyes open",
            glassesRequirement: "No eyeglasses unless a documented medical exception applies; frames, glare and shadows must not obscure the eyes",
            sourceURL: url("https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-dv-lottery-2026-10-25",
                    date: verifiedDate,
                    note: "DV digital workflow: 600 × 600 JPEG, no more than 240 kB, head including hair at 50–69% of image height and eye line at 56–69% from the bottom."
                )
            ]
        )
    ]

    // https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/photo-composition-template.html
    // These digital percentages are authoritative; converting rounded printed
    // millimetres back to fractions creates contradictory boundary decisions.
    private static let digitalHeadHeightRange = (50.8 * 0.50)...(50.8 * 0.69)
    private static let digitalEyeLineRange = (50.8 * 0.56)...(50.8 * 0.69)

    static func document(id: String) -> DocumentSpec? {
        documents.first { $0.id == id }
    }

    private static let verifiedDate: Date = makeDate(year: 2026, month: 10, day: 25)

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
