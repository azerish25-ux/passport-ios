//
//  DocumentCorpus.swift
//  PassportProof
//
//  Five complete workflows across three countries. No empty catalogue slots and
//  no output that contradicts the issuer's printed-versus-digital guidance.
//

import Foundation

struct DocumentCountry: Identifiable, Sendable {
    let name: String
    let code: String
    let documents: [DocumentSpec]

    var id: String { code }
}

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
            sourceURL: url("https://travel.state.gov/en/passports/apply/help/photos.html"),
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
        ),

        DocumentSpec(
            id: "ca-passport",
            country: "Canada",
            countryCode: "CA",
            documentName: "Passport",
            workflow: .printedPhoto,
            widthMM: 50,
            heightMM: 70,
            widthPixels: 600,
            heightPixels: 840,
            headHeightMM: 31...36,
            headMeasurement: .skull,
            headHeightShare: nil,
            eyeLineFromBottomMM: nil,
            maximumPhotoAgeMonths: 6,
            maximumFileSizeBytes: nil,
            backgroundDescription: "Plain white or light-coloured, with no shadows or objects",
            expressionRequirement: "Neutral expression, mouth closed, with both eyes open and clearly visible",
            glassesRequirement: "No sunglasses; eyeglasses must not hide the eyes or cast a shadow",
            sourceURL: url("https://www.canada.ca/en/immigration-refugees-citizenship/services/canadian-passports/photos.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "ca-passport-2026-10-26",
                    date: verifiedDate,
                    note: "Printed-photo workflow verified against IRCC guidance: 50 × 70 mm, chin to crown of the head at 31–36 mm (hair excluded), taken within six months."
                )
            ]
        ),

        DocumentSpec(
            id: "de-schengen-visa",
            country: "Germany",
            countryCode: "DE",
            documentName: "Schengen visa",
            workflow: .printedPhoto,
            widthMM: 35,
            heightMM: 45,
            widthPixels: 420,
            heightPixels: 540,
            headHeightMM: 32...36,
            headMeasurement: .skull,
            headHeightShare: nil,
            eyeLineFromBottomMM: nil,
            maximumPhotoAgeMonths: 3,
            maximumFileSizeBytes: nil,
            backgroundDescription: "Plain white or off-white, without shadows or pattern",
            expressionRequirement: "Neutral expression, mouth closed, eyes open and directed at the camera",
            glassesRequirement: "No tinted lenses; frames must not cover the eyes or reflect the light",
            sourceURL: url("https://uk.diplo.de/uk-en/02/visa/visa-faq-2442852"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "de-schengen-visa-2026-10-26",
                    date: verifiedDate,
                    note: "Printed-photo workflow verified against the German Foreign Office visa FAQ: 35 × 45 mm, face 32–36 mm (70–80% of the photo), no older than three months. This is the German Schengen profile, not a claim that every member state applies identical details."
                )
            ]
        ),
    ]

    // https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/photo-composition-template.html
    // These digital percentages are authoritative; converting rounded printed
    // millimetres back to fractions creates contradictory boundary decisions.
    private static let digitalHeadHeightRange = (50.8 * 0.50)...(50.8 * 0.69)
    private static let digitalEyeLineRange = (50.8 * 0.56)...(50.8 * 0.69)

    static func document(id: String) -> DocumentSpec? {
        documents.first { $0.id == id }
    }

    /// The catalogue grouped by issuing country, in corpus order. Grouping is
    /// derived from the corpus rather than maintained as a second list, so a
    /// document can never appear under the wrong country or go missing from
    /// the library.
    static var countries: [DocumentCountry] {
        var order: [String] = []
        var grouped: [String: [DocumentSpec]] = [:]
        for document in documents {
            if grouped[document.countryCode] == nil { order.append(document.countryCode) }
            grouped[document.countryCode, default: []].append(document)
        }
        return order.compactMap { code in
            guard let items = grouped[code], let first = items.first else { return nil }
            return DocumentCountry(name: first.country, code: code, documents: items)
        }
    }

    /// The default document offered by the library's primary action.
    static var featured: DocumentSpec? { document(id: "us-passport") }

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
