//
//  DocumentCorpus.swift
//  PassportProof
//
//  Four documents, encoded. Not twelve. The corpus says so on the surface:
//  `launchTargetCount` is 12 and `pendingDocumentNames` is the honest remainder.
//
//  Head height is 25.4–34.9 mm for every US document. The 22 mm metric clause
//  printed on the State Department's visa page contradicts the imperial clause
//  and the 50–69% proportion clause, and is wrong by 3.4 mm. It is not encoded
//  anywhere in this file, by design.
//

import Foundation

enum DocumentCorpus {

    // MARK: - Coverage

    static let launchTargetCount: Int = 12

    /// The eight of twelve that this build does not encode. Named as slots
    /// rather than as countries: the sources never enumerate them, and naming
    /// a country would imply coverage the corpus does not have.
    static let pendingDocumentNames: [String] = [
        "Document 05 — not encoded",
        "Document 06 — not encoded",
        "Document 07 — not encoded",
        "Document 08 — not encoded",
        "Document 09 — not encoded",
        "Document 10 — not encoded",
        "Document 11 — not encoded",
        "Document 12 — not encoded"
    ]

    // MARK: - Documents

    /// Ordered: US passport, US visa, DV-2026, UK passport.
    static let documents: [DocumentSpec] = [
        DocumentSpec(
            id: "us-passport",
            country: "United States",
            countryCode: "US",
            documentName: "Passport",
            widthMM: 51,
            heightMM: 51,
            widthPixels: 600,
            heightPixels: 600,
            headHeightMM: 25.4...34.9,
            headHeightShare: nil,
            eyeLineFromBottomMM: nil,
            backgroundDescription: "Plain white or off-white background",
            sourceURL: url("https://travel.state.gov/content/travel/en/passports/how-apply/photos.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-passport-2026-10-24",
                    date: verifiedDate,
                    note: "Head height encoded as 25.4–34.9 mm from the imperial clause, corroborated by the 50–69% proportion clause. The metric clause's lower bound is rejected as inconsistent with the definition of an inch."
                )
            ],
            isPrototypeData: true
        ),

        DocumentSpec(
            id: "us-visa",
            country: "United States",
            countryCode: "US",
            documentName: "Visa",
            widthMM: 51,
            heightMM: 51,
            widthPixels: 600,
            heightPixels: 600,
            headHeightMM: 25.4...34.9,
            headHeightShare: nil,
            eyeLineFromBottomMM: 28...35,
            backgroundDescription: "Plain white or off-white background",
            sourceURL: url("https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-visa-2026-10-24",
                    date: verifiedDate,
                    note: "Eye line encoded at 28–35 mm measured up from the bottom edge of the photo."
                )
            ],
            isPrototypeData: true
        ),

        DocumentSpec(
            id: "us-dv-2026",
            country: "United States",
            countryCode: "US",
            documentName: "DV-2026 lottery entry",
            widthMM: 51,
            heightMM: 51,
            widthPixels: 600,
            heightPixels: 600,
            headHeightMM: 25.4...34.9,
            headHeightShare: 0.50...0.69,
            eyeLineFromBottomMM: nil,
            backgroundDescription: "Plain white or off-white background",
            sourceURL: url("https://dvprogram.state.gov/"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "us-dv-2026-2026-10-24",
                    date: verifiedDate,
                    note: "Head height encoded as a share of image height: 50–69%, which on a 51 mm image resolves to 25.5–35.2 mm."
                )
            ],
            isPrototypeData: true
        ),

        DocumentSpec(
            id: "uk-passport",
            country: "United Kingdom",
            countryCode: "GB",
            documentName: "Passport",
            widthMM: 35,
            heightMM: 45,
            widthPixels: 413,
            heightPixels: 531,
            headHeightMM: 29...34,
            headHeightShare: nil,
            eyeLineFromBottomMM: nil,
            backgroundDescription: "Plain light grey or cream background",
            sourceURL: url("https://www.gov.uk/photos-for-passports"),
            verifiedOn: verifiedDate,
            changelog: [
                ChangelogEntry(
                    id: "uk-passport-2026-10-24",
                    date: verifiedDate,
                    note: "35 × 45 mm at 413 × 531 px. Head height 29–34 mm, chin to crown."
                )
            ],
            isPrototypeData: true
        )
    ]

    // MARK: - Lookup

    static func document(id: String) -> DocumentSpec? {
        documents.first { $0.id == id }
    }

    // MARK: - Private

    /// All four documents were read on the same date, the date of the research
    /// report they are drawn from. Fixed rather than "today" so the corpus is
    /// reproducible and the tests are deterministic.
    private static let verifiedDate: Date = makeDate(year: 2026, month: 10, day: 24)

    private static func makeDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        components.minute = 0
        components.second = 0
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0) ?? TimeZone.current
        return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
    }

    private static func url(_ string: String) -> URL {
        // Literal constants, all well-formed. Falling back to a file URL keeps
        // this non-optional without a force unwrap.
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }
}
