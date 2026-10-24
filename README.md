# PassportProof — iOS prototype

[![iOS Build](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml/badge.svg)](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml)

A working SwiftUI prototype of **PassportProof**, built to the engineering
specification extracted from the research report in the parent workspace
(`PassportProof-iOS-App-Research-Report.md` v2.0).

> **Read this before judging the repo.** The research report's own conclusion is
> that the *consumer business* should not be built: the channel is closed, the
> instrument is priced at the cost of the failure it prevents, and the expected
> value is negative at every probability. This prototype exists to test the
> *engineering* claims in Chapter 6 — that a diagnosis-only validator with
> print-sheet export is buildable and that its measurement model behaves — not
> to endorse the commercial case. Building it does not make the arithmetic go
> away.

---

## What it does

Pick a document, give it a photo, and the app measures the photo against that
document's published rules and reports **pass / fail / cannot verify** per rule,
with the measured value and the required range. Then it exports a 300 DPI print
sheet or a portal-sized digital file.

Six features, from §2.6 of the report:

1. Capture and auto-crop to a chosen document's spec
2. Background compliance diagnosis with reshoot guidance
3. A pre-export check on head size, eye line, centring, shadow, expression, glasses
4. Print-sheet export at 300 DPI
5. A digital export sized for the online application portal
6. A document spec library with a dated changelog

Six prohibitions, also from §2.6 — these are architectural, and each is visible
in the code:

| Prohibition | How it is honoured |
|---|---|
| Do not store photos | `PhotoSession` holds the image in memory only. No cache write, no Core Data blob, no Photos save. |
| Do not require an account | No auth, no onboarding wall. Cold launch lands on the library. |
| Do not ship a subscription | One non-consumable, `com.passportproof.app.unlock`, $17.99. No auto-renewable product exists. |
| Do not synthesise a background | Segmentation is read for measurement only. There is no code path that writes pixels behind the subject. |
| Do not call a server | No analytics, no remote config, no networking. StoreKit is the only network surface and it is Apple's. |
| Do not promise approval | Three-state findings, and a disclaimer on the Diagnose screen. The word "approved" does not appear as a claim. |

## The measurement model

The interesting part of this app is not the camera — it is that the regulated
measurement is **chin to the top of the skull**, and no Apple framework exposes a
crown point. `VNFaceLandmarks2D.faceContour` runs cheek to cheek *under* the
chin; `VNFaceObservation.boundingBox` tops out near the brow. A silhouette scan
recovers the **outer envelope** — the top of the hair — which for an updo, a
turban, a hijab or a wig sits materially above the crown.

So the app runs **two estimators**:

- the silhouette envelope, from the image itself, and
- a crown inferred from chin-to-eye-line proportions (the eye line sits at the
  midpoint of crown and chin on a typical head).

When they diverge by more than 6% of measured head height, the rule reports
**`cannot verify`** — never pass, never fail. That third state is the honest form
of "this app does not promise approval", and it is the reason the engine is not
a boolean.

The 6% tolerance, and the thresholds for shadow, centring and the crown-contrast
gate, are **prototype defaults**: the research documents name those checks but
publish no tolerance for them. They carry `Provenance.prototypeDefault` and the
UI labels them as such. Values that *are* sourced — head height, eye line,
resolution, photo age — carry their clause and verification date.

### The 22 mm clause

The State Department's visa page states head height as "between 1 inch and
1 3/8 inches (22 mm and 35 mm)". One inch is 25.4 mm, so the metric lower bound
is wrong by 3.4 mm; the page's own 50–69% proportion clause (25.5–35.2 mm on a
51 mm image) corroborates 25.4. This corpus encodes **25.4–34.9 mm** and a test
asserts the value 22 never appears. A naive scraper gets this wrong and rejects
compliant photos.

## Corpus

**Four documents encoded, not twelve.** The research names only four US-family
documents and the UK, and never enumerates the launch twelve. Inventing eight
more would fabricate provenance, so the library shows `4 OF 12 DOCUMENTS ENCODED`
and lists the remaining eight as unencoded slots. Coverage is never implied.

| id | Document | Photo | Head height |
|---|---|---|---|
| `us-passport` | US Passport | 51 × 51 mm, 600 × 600 px | 25.4 – 34.9 mm |
| `us-visa` | US Visa | 51 × 51 mm, 600 × 600 px | 25.4 – 34.9 mm, eye line 28 – 35 mm |
| `us-dv-2026` | DV-2026 entry | 51 × 51 mm, 600 × 600 px | 25.4 – 34.9 mm, 50 – 69% of height |
| `uk-passport` | UK Passport | 35 × 45 mm, 413 × 531 px | 29 – 34 mm |

All four are flagged `isPrototypeData`. They have not been through the report's
2.5–4 documents/person-day verification programme and must not be treated as
production corpus data.

## Print geometry

The non-obvious result from §6.3: **no margined tiling of exactly-2-inch cells
exists on 4×6**, because 4 and 6 are both exact multiples of 2. A zero-remainder
layout has no margin to absorb a printer's 3–6 mm non-printable edge, so the
outermost photos lose 3–6 mm — and a photo trimmed to 1.88 in is not a 2×2 in
photo. The 4×6 sheet therefore ships **borderless only**, with a calibration
sheet to prove the printer is not scaling.

| Layout | Grid | Page (pt) | Margins |
|---|---|---|---|
| 4×6 in | 2 × 2 (4-up) | 288 × 432 | borderless |
| 5×7 in | 2 × 3 (6-up) | 360 × 504 | 0.5 in all edges |
| Letter | 3 × 4 (12-up) | 612 × 792 | 1.25 in sides, 0.25 in row gutters |
| Letter | 4 × 5 (20-up) | 612 × 792 | 0.25 in sides |

Every sheet carries **"PRINT AT 100% — DO NOT SCALE"**, because the printer
driver's default is often "fit to page", and the same file at three settings
yields three physical sizes. The calibration sheet prints without consuming the
unlock.

## Building

The app is authored on Windows, where no Xcode toolchain exists, so **CI is the
only place it is ever compiled** and is the source of truth for whether it builds.

**In CI** (`.github/workflows/ios-build.yml`, macOS 15):

```
Generate Xcode project → build for iOS Simulator → resolve a simulator → run unit tests
                        → (parallel) unsigned Release build for generic iOS device
```

**Locally on macOS** (Xcode 16+):

```bash
python3 Tools/generate_project.py      # regenerate the project from the tree
xcodebuild -project PassportProof.xcodeproj -scheme PassportProof \
  -destination 'generic/platform=iOS Simulator' build
```

`PassportProof.xcodeproj` is committed so the repo opens in Xcode, but
`Tools/generate_project.py` is authoritative and CI regenerates it. The
generator exists because a hand-maintained `project.pbxproj` authored without
Xcode drifts: a file lands on disk, is never added to the target, and the failure
appears twenty minutes later as a link error. Generating from the tree removes
that class of bug.

### Dependencies

**None.** No SPM packages, no CocoaPods, no Carthage. Apple frameworks only:
SwiftUI, Vision, PhotosUI, UIKit, CoreGraphics, ImageIO, StoreKit. This is a
deliberate choice for a prototype that cannot be built locally — every external
dependency would be an unverifiable variable in a CI-only build.

## Layout

```
PassportProof/
  App/          entry point, routing, session state, shared components
  Core/
    Models/     Finding, DocumentSpec — the vocabulary
    Corpus/     the four encoded documents
    Validation/ face geometry, background analysis, rule engine, capture gate
    Print/      sheet layouts and PDF rendering
    Export/     portal-sized JPEG with DPI metadata
    Store/      StoreKit 2 entitlement
  Design/       Theme.swift — colour, type, space, stroke, motion
  Features/     Library, Capture, Analysis, Export, Unlock
PassportProofTests/   rule-engine, print-geometry and corpus-integrity tests
docs/                 SPEC.md, BUILD-CONTRACT.md
Tools/                project generator
```

## Documentation

- `docs/SPEC.md` — the engineering spec extracted from the research, with every
  figure traced to a section and every gap marked.
- `docs/BUILD-CONTRACT.md` — the team lead's adjudication of those gaps and the
  frozen API surface the implementation was written against.
- `DesignSystem.md` — palette, type scale, component metrics, motion.

## Known deviations from the spec

Three, all deliberate and all visible in the UI:

1. **AC10 — the capture gate blocks the shutter, not the import.** §6.2's gate
   exists to guarantee a plain, evenly lit background *before* the shutter
   releases, and it does: on the camera path, the shutter is disabled while
   `CaptureGate` fails. On the photo-library path there is no shutter to gate,
   and blocking import would make the app undemonstrable in the simulator. An
   imported photo therefore runs the full diagnosis exactly as imported: the
   engine never consults the gate, so a busy background produces a genuine
   **fail** on `backgroundUniformity` and `shadow`. `cannot verify` on those two
   rules happens only when no face is found at all. The capture screen says this
   in as many words. AC10 holds for the path it was written about.
2. **`photoAge` reports `cannot verify`, not pass/fail.** §3.1 R7 gives a
   six-month limit, but the rule needs a *submission* date and the app has no
   submission. Testing capture date against "now" would be a proxy presented as
   a measurement, so the rule states the limit, shows the capture date when EXIF
   has one, and declines to adjudicate. This is the same discipline as the crown
   divergence rule.
3. **Four documents, not twelve.** See *Corpus* above.

## Status

Prototype. Not shipped, not signed, not submitted. The StoreKit product is not
configured against App Store Connect, so the unlock falls back to a clearly
labelled prototype bypass that never reports a successful purchase.
