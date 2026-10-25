# Build Contract — PassportProof prototype

> **Historical contract, superseded.** The current implementation narrows the
> corpus to three complete US workflows, adds a user-reviewed crop and visual
> confirmations, removes the Release prototype bypass, and enforces
> document-specific digital byte limits. Use [`README.md`](../README.md) and
> [`RELEASE.md`](RELEASE.md) for the shipped contract. This file remains as the
> original research-to-engineering decision record.

**Owner:** team lead. **Status:** binding on all implementers.
This document resolves the gaps listed in `docs/SPEC.md` §10 and fixes the exact
public API surface. Code written against this contract compiles without
negotiation; anything not declared here is not part of the surface.

---

## 1. Adjudication of the spec's open gaps

| Gap | Decision | Rationale |
|---|---|---|
| **G1** — 12 documents never enumerated | Ship **4 fully encoded documents** and expose the corpus as `4 of 12 encoded`, with the remaining 8 listed as *not encoded*. | The report names only four US-family documents plus UK at launch order 2. Inventing eight more would fabricate provenance — the one thing the report forbids. A visible "4 of 12" is also the honest form of risk 7 ("never imply coverage"). |
| **G2** — no tolerances for eye line, centring, shadow, expression, glasses | Implement all five. Numeric ones use `Provenance.prototypeDefault` and are labelled **"prototype default — not from source"** in the UI. Expression and glasses return `cannotVerify` where no reliable signal exists. | A screen of five `cannotVerify` rows demonstrates nothing. Labelled defaults demonstrate the engine while keeping provenance honest. |
| **G3** — headroom absent from sources | No headroom rule. Headroom is *derived* for display from the head-height band only. | Cannot invent a rule that has no source. |
| **G4** — divergence tolerance unspecified | **6% of measured head height.** Beyond it → `cannotVerify`. | Small enough to catch updos, large enough to survive landmark noise. Labelled prototype default. |
| **G5** — 4×6 described as both 4-up and 2×3; 12-up margins do not close on Letter | 4×6 = **4-up (2×2)**. Letter 12-up = **1.25 in sides, 0.25 in row gutters, 1.125 in top/bottom, 0 column gutters.** | Uses the spec's own derived values; 2×3 would be 6-up and contradicts the layout list. |
| **G6** — crown-contrast gate unthresholded | Shutter gate: background σ ≤ **0.045**, crown local contrast ≥ **0.18**, face detected, head inside band ±15%. | Prototype defaults, tunable in one struct. |
| **G7** — auto-crop legality inferred | Auto-crop is **geometric only**: rotate, scale, translate, crop. Never resample content into existence, never inpaint. | Matches §4.3's reading. Enforced by the absence of any synthesis code path. |
| **G8** — digital export unspecified | **JPEG, sRGB, quality 0.95, at the document's exact pixel geometry, 300 DPI in JFIF metadata.** | Portal-standard, and 300 DPI as metadata is exactly what ref 15 says DPI is. |
| **G9** — no minimum input resolution | Require source ≥ **1200 × 1200 px**; below that the resolution rule fails with a named threshold. | 2× the 600 px cell, so the crop has room to move. |
| **G10** — no design guidance | Governed by `DesignSystem.md` and `Theme.swift`. | Already delivered. |

---

## 2. The corpus — four documents, encoded

All values are public issuer guidance. Every document carries `verifiedOn` and a
`sourceURL`, and every one is flagged `isPrototypeData = true` because the corpus
has not been through the report's 2.5–4 docs/person-day verification process.

| id | Country | Document | Photo | Head height | Extra |
|---|---|---|---|---|---|
| `us-passport` | United States | Passport | 2 × 2 in → **51 × 51 mm**, 600 × 600 px | **25.4 – 34.9 mm** | Plain white / off-white background |
| `us-visa` | United States | Visa | **51 × 51 mm**, 600 × 600 px | **25.4 – 34.9 mm** | Eye height **28 – 35 mm** from bottom |
| `us-dv-2026` | United States | DV-2026 lottery entry | **51 × 51 mm**, 600 × 600 px | **25.4 – 34.9 mm** | Head = 50 – 69% of image height |
| `uk-passport` | United Kingdom | Passport | **35 × 45 mm**, 413 × 531 px | **29 – 34 mm** | Plain light grey or cream background |

**The 22 mm rule must never appear.** `25.4` is the lower bound everywhere.
A test asserts the literal `22` is absent from the corpus.

---

## 3. Public API surface — exact declarations

Implementers may add `private` helpers freely. These declarations are fixed.

```swift
// Core/Models/Finding.swift
enum FindingStatus: String, Codable, Sendable, CaseIterable { case pass, fail, cannotVerify }
enum RuleID: String, Codable, Sendable, CaseIterable {
    case headHeight, headHeightShare, eyeLine, centring,
         backgroundUniformity, shadow, expression, glasses,
         resolution, photoAge, noManipulation
}
enum Provenance: String, Codable, Sendable { case source, derived, prototypeDefault }

struct Measurement: Sendable, Equatable {
    let value: Double            // in `unit`
    let unit: String             // "mm" | "%" | "px"
    let lowerBound: Double?
    let upperBound: Double?
    let displayValue: String     // "27.4 mm"
    let displayRange: String     // "25.4 – 34.9 mm"
}

struct Finding: Identifiable, Sendable {
    let id: RuleID
    let title: String
    let status: FindingStatus
    let detail: String           // why it failed / what to do
    let measurement: Measurement?
    let provenance: Provenance
}

// Core/Models/DocumentSpec.swift
struct ChangelogEntry: Identifiable, Sendable {
    let id: String
    let date: Date
    let note: String
}

struct DocumentSpec: Identifiable, Sendable {
    let id: String
    let country: String
    let countryCode: String
    let documentName: String
    let widthMM: Double
    let heightMM: Double
    let widthPixels: Int
    let heightPixels: Int
    let headHeightMM: ClosedRange<Double>
    let headHeightShare: ClosedRange<Double>?
    let eyeLineFromBottomMM: ClosedRange<Double>?
    let backgroundDescription: String
    let sourceURL: URL
    let verifiedOn: Date
    let changelog: [ChangelogEntry]
    let isPrototypeData: Bool
    var displayName: String { "\(country) — \(documentName)" }
    var pixelSize: CGSize { CGSize(width: widthPixels, height: heightPixels) }
}

// Core/Corpus/DocumentCorpus.swift
enum DocumentCorpus {
    static let documents: [DocumentSpec]          // exactly 4, ordered US passport, US visa, DV, UK
    static let launchTargetCount: Int             // 12
    static let pendingDocumentNames: [String]     // the 8 not encoded
    static func document(id: String) -> DocumentSpec?
}

// Core/Validation/FaceGeometry.swift
struct FaceGeometry: Sendable {
    let chinY: Double          // normalized, 0 = top of image, 1 = bottom
    let eyeY: Double
    let crownEnvelopeY: Double // top of hair/silhouette
    let crownInferredY: Double // from chin→eye proportions
    let faceCenterX: Double    // normalized 0...1
    let faceWidth: Double      // normalized
    let faceBox: CGRect        // normalized, origin TOP-left
}
enum FaceAnalyzer {
    static func geometry(of image: CGImage) -> FaceGeometry?
}

// Core/Validation/BackgroundAnalyzer.swift
struct BackgroundReport: Sendable {
    let uniformitySigma: Double        // 0...1
    let crownContrast: Double          // 0...1
    let edgeResidualFraction: Double   // 0...1
    let failingRegions: [CGRect]       // normalized, origin top-left
}
enum BackgroundAnalyzer {
    static func analyze(_ image: CGImage, faceBox: CGRect) -> BackgroundReport
}

// Core/Validation/ValidationEngine.swift
struct PhotoAnalysis: Sendable {
    let findings: [Finding]
    let geometry: FaceGeometry?
    let background: BackgroundReport?
    let overall: FindingStatus
    var failures: [Finding] { findings.filter { $0.status == .fail } }
}
enum ValidationEngine {
    static func analyze(image: CGImage, spec: DocumentSpec) -> PhotoAnalysis
}

// Core/Validation/CaptureGate.swift
struct CaptureGateResult: Sendable {
    let canCapture: Bool
    let message: String
    let headTopFraction: Double?    // 0...1 from top
    let headBottomFraction: Double?
}
enum CaptureGate {
    static func evaluate(frame: CGImage, spec: DocumentSpec) -> CaptureGateResult
}

// Core/Print/PrintSheetLayout.swift
enum PrintSheetLayout: String, CaseIterable, Identifiable, Sendable {
    case fourBySix, fiveBySeven, letter12, letter20
    var id: String { rawValue }
    var title: String
    var subtitle: String
    var pageSizePoints: CGSize        // 72 dpi points
    var columns: Int
    var rows: Int
    var cellInsetPoints: CGFloat      // gutter allowance around each cell
    var supportsCutMarks: Bool
}
struct PrintSheetRenderer {
    static func pdfData(photo: CGImage, layout: PrintSheetLayout, spec: DocumentSpec) -> Data?
    static func calibrationPDFData(layout: PrintSheetLayout) -> Data?
}

// Core/Export/DigitalExport.swift
enum DigitalExport {
    static func jpegData(from image: CGImage, spec: DocumentSpec) -> Data?
}

// Core/Store/EntitlementStore.swift
@MainActor final class EntitlementStore: ObservableObject {
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var displayPrice: String
    @Published private(set) var state: EntitlementState
    func refresh() async
    func purchase() async
    func restore() async
}
enum EntitlementState: Equatable, Sendable {
    case loading, available, purchased, unavailable(String), failed(String)
}
```

`EntitlementStore` uses StoreKit 2. When no product is configured (the normal
case for a prototype with no App Store Connect record) it must set
`state = .unavailable("No StoreKit product configured — prototype build")` and
offer `unlockForPrototype()`, which is clearly labelled as a prototype bypass.
It must never claim a purchase succeeded.

---

## 4. Layout rules the UI must honour

- **Root** is a `NavigationStack` over `AppRoute`. No tab bar.
- Cold launch lands on **Library** with the corpus visible (satisfies AC1 without
  a sign-in wall; camera permission is requested only on first capture).
- Screen order: **Library → Document detail → Capture/Import → Diagnose → Print/Export**.
- Every finding row shows: rule title, status, measured value, required range,
  and a measurement bar. `cannotVerify` is a first-class state with its own colour.
- The disclaimer appears on the Diagnose screen, not buried in settings:
  *"Informational diagnosis. This app does not determine whether a document will
  be issued."* No use of "approved", "guaranteed", "official", "accepted".
- Library header shows `4 of 12 documents encoded`.

---

## 5. Definition of done

1. `xcodebuild build -destination 'generic/platform=iOS Simulator'` succeeds.
2. `xcodebuild test` passes on the resolved simulator.
3. No `import` outside Apple frameworks.
4. No network call, no persistence of image data, no background synthesis.
5. Every finding is `pass` / `fail` / `cannotVerify` — never a bare boolean.
