# PassportProof

[![iOS Build](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml/badge.svg)](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml)

PassportProof is a native SwiftUI photo workflow for US passport, visa and DV Lottery applications. It guides capture, checks the prepared photograph where reliable measurements are available, asks for visual review, and formats the exact reviewed crop as a print sheet or JPEG. A separately labelled manual-framing path is available when automatic face measurements are unavailable.

Analysis and export happen on device. There is no account, analytics SDK, application backend or photo upload.

## Supported workflows

| Workflow | Output | Geometry | Head height | Other checks |
|---|---|---|---|---|
| US Passport | Printed sheet | 2 × 2 in, 600 × 600 px at 300 DPI | 25–35 mm | 6-month recency, background, expression, glasses |
| US Visa | Digital upload | 600 × 600 JPEG, ≤ 240 kB | Including hair, 50–69% of frame | Eyes 56–69% from bottom, 6-month recency |
| DV Lottery | Digital upload | 600 × 600 JPEG, ≤ 240 kB | Including hair, 50–69% of frame | Eyes 56–69% from bottom, 6-month recency |
| Canada Passport | Printed sheet | 50 × 70 mm, 600 × 840 px | Chin to crown, 31–36 mm | 6-month recency, white or light background |
| German Schengen Visa | Printed sheet | 35 × 45 mm, 420 × 540 px | Face 32–36 mm | 3-month recency, white or off-white background |

The catalogue deliberately contains only complete workflows, each with the
issuing authority's own figures and a dated source link. Two omissions are
deliberate: the UK's printed rule forbids a cut-down larger picture while its
digital rule requires at least 600 × 750 px and says not to crop, and Canada's
digital renewal specification has a minimum file size and a 3:2 frame that no
single generic export can share with the printed workflow. Neither is
approximated.

Print grids are derived from each document's real physical size, so a
35 × 45 mm or 50 × 70 mm photo is printed at true scale rather than being
stretched to fill a 2 × 2 inch cell.

## Product flow

1. **Capture or import.** A custom `AVCaptureSession` camera evaluates background, crown contrast and framing before enabling its shutter. Library images go through the same crop step.
2. **Review one crop.** A face-aware starting crop is adjustable with pan, zoom, quarter-turn rotation, reset and auto framing. The original stays in memory so users can return from analysis and edit it. Only the accepted crop feeds diagnosis and export; accepting a new crop resets its review.
3. **Check the prepared pixels.** Vision attempts face geometry; pixel analysis uses reliable geometry for background, shadow and glare signals. Findings are `pass`, `fail` or `review`. White/off-white screening is separate from uniformity; unavailable geometry, unknown crown measurements and ambiguous natural edges remain unresolved.
4. **Review framing and human checks.** When automatic geometry is unavailable, the user can place head, chin, eye and centre guides on the actual crop. Manual dimensions must meet the selected workflow's ranges and require explicit confirmations of guide placement, one front-facing subject, background/lighting and the limits of manual formatting. This record never becomes detected geometry, and automatic findings stay unresolved. Expression, glasses/eye visibility, recency and original-source status still require their four separate confirmations. A new crop clears both reviews.
5. **Export safely.** Failed applicable checks block export. Digital files are compressed within the issuer's byte ceiling, and print sheets carry exact page geometry plus a free calibration page. Print preview uses the actual PDF renderer. Protected share staging is removed on completion or cancellation, with abandoned files cleaned at the next launch.

## Privacy

- The bounded original and prepared crop are held in memory until the session ends or the user erases them. The app does not create a photo archive; only an explicit export creates a temporary share file.
- No tracking, advertising identifier, analytics or remote configuration.
- `PrivacyInfo.xcprivacy` declares no collected data and no tracking.
- StoreKit is the only purchase surface and uses Apple's network services.
- An opaque privacy cover hides session photos in the app switcher.
- In-app disclosure lives at **Library → Privacy**; ready-to-host policy text is
  in [`docs/PRIVACY.md`](docs/PRIVACY.md).

## Architecture

```
PassportProof/
  App/          entry point, routing, session state, privacy cover, shared components
  Core/
    Models/     document, finding, visual-review vocabulary
    Corpus/     three verified US workflows with dated provenance
    Imaging/    one crop transform shared by editor and outputs
    Validation/ face geometry, background analysis, rule engine, live capture gate
    Print/      physical layouts and PDF rendering
    Export/     bounded JPEG encoding at exact portal geometry
    Store/      StoreKit 2 entitlement and verified transaction updates
  Design/       adaptive palette, scalable type, spacing and motion
  Features/     Library, Capture, Analysis, Export, Unlock
PassportProofTests/    logic, imaging, export and compiled-bundle checks
PassportProofUITests/  navigation, appearance, photo workflow and StoreKit UI tests
Tools/                 deterministic project and brand-asset generation
docs/                  production audit, release checklist, QA and historical specification
```

Apple frameworks only: SwiftUI, Vision, AVFoundation, PhotosUI, UIKit, CoreGraphics, ImageIO and StoreKit. There are no SPM, CocoaPods or Carthage dependencies.

## Build and verification

The app is authored on Windows, so macOS/Xcode CI is the source of truth for compilation and simulator execution. `PassportProof.xcodeproj` is generated from the source tree and committed; CI regenerates it before building.

```bash
python3 Tools/generate_project.py
python3 Tools/generate_icon.py
xcodebuild -project PassportProof.xcodeproj -scheme PassportProof \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
xcodebuild build -project PassportProof.xcodeproj -scheme PassportProof \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

The GitHub Actions workflow runs on `macos-15` and:

- builds for the iOS Simulator;
- discovers and erases a disposable Actions iPhone simulator, then seeds one licensed full-resolution photo;
- runs unit and XCUITest suites and uploads `.xcresult`, logs, diagnostics and screenshots;
- requires no skipped tests or expected failures for a successful unit gate;
- seeds a synthetic original through a DEBUG-only launch argument so UI journeys do not depend on the photo picker or on the simulator detecting a face;
- uses the canonical local StoreKit configuration in the test bundles for purchase, restore, cancellation, pending approval and refund checks;
- compiles an unsigned arm64 Release device build;
- audits the built bundle for the icon, launch symbol, privacy manifest, usage descriptions and absence of DEBUG unlock strings;
- publishes every compiler error and failing test as a workflow annotation (`Tools/ci_report.py`), so a red run is diagnosable without the `.xcresult`.

## Pricing

Checks are free. Export is either one consumable credit or one non-consumable
unlimited purchase — no subscription. Single-export credits are device-local and
cannot be restored by Apple; the purchase screen says so. The unlimited purchase
is restored from verified StoreKit transactions on launch and through
**Restore purchase**. Prices live in App Store Connect; the fallback strings in
the binary are only shown when StoreKit metadata is unavailable.

## Release status

Automatic landmark accuracy remains unvalidated. Isolated Apple-framework probes
reproduce incorrect and drifting landmarks on both arm64 and Intel iOS
Simulators while the native macOS control is stable, across the modern async
API, legacy revision 1 and several landmark constellations. This does not
establish an Apple-confirmed cause or prove behaviour on an iPhone.

That evidence drove a deliberate change of policy. Gating the product pipeline
on a machine-specific third-party failure produced a permanently red build,
which hides real regressions and makes "does it still work" unanswerable.
Strict photographic landmark accuracy is therefore measured where it can be
measured — `Tools/VisionProbe.swift` in the **Isolated Vision diagnostic**
workflow, which fails loudly and records its evidence — while the gating suite
asserts the application's own contract: the applicable rule set per document,
that missing geometry never becomes a confident measurement, crop geometry, the
JPEG byte ceiling, catalogue invariants and the print grid.

The app can therefore be described honestly: guide-assisted framing with an
automatic assist. When automatic measurement is unavailable, the user places
four guides and the published ranges are checked exactly; those results are
always labelled as manually framed.

Use the Actions result for the exact commit as build/test evidence; do not infer
camera reliability, printer fidelity, issuer acceptance or live App Store
product availability from compilation or a successful manual export. Local
StoreKit Test transactions are simulated and never charge real money. Signing,
the live App Store Connect products, hosted privacy/support URLs, App Store
ranking and revenue remain external, and are documented in
[`docs/RELEASE.md`](docs/RELEASE.md).

The measurement engine labels app-selected thresholds separately from issuer rules. It does not promise approval, and the final decision always belongs to the issuing authority. Physical-camera and printer calibration still require real-device QA, as recorded in [`docs/MANUAL-QA.md`](docs/MANUAL-QA.md).

The baseline gap analysis that drove this pass is in [`docs/PRODUCTION-AUDIT.md`](docs/PRODUCTION-AUDIT.md). `docs/SPEC.md` and `docs/BUILD-CONTRACT.md` are retained as historical research artifacts; the current scope is defined by this README and the corpus.

The October 25 repair and design changes are recorded in [`docs/IMPROVEMENTS-2026-10-25.md`](docs/IMPROVEMENTS-2026-10-25.md).
