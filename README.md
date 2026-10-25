# PassportProof

[![iOS Build](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml/badge.svg)](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml)

PassportProof is a native SwiftUI photo workflow for US passport, visa and DV Lottery applications. It guides capture, diagnoses the prepared photograph against published issuer requirements, asks for the visual checks software cannot prove, and exports the exact reviewed crop as a print sheet or portal-ready JPEG.

Analysis and export happen on device. There is no account, analytics SDK, application backend or photo upload.

## Supported workflows

| Workflow | Output | Geometry | Head height | Other checks |
|---|---|---|---|---|
| US Passport | Printed sheet | 2 × 2 in, 600 × 600 px at 300 DPI | 25–35 mm | 6-month recency, background, expression, glasses |
| US Visa | Digital upload | 600 × 600 JPEG, ≤ 240 kB | Including hair, 50–69% of frame | Eyes 56–69% from bottom, 6-month recency |
| DV Lottery | Digital upload | 600 × 600 JPEG, ≤ 240 kB | Including hair, 50–69% of frame | Eyes 56–69% from bottom, 6-month recency |

The catalogue deliberately contains only complete workflows. The earlier UK entry was removed because GOV.UK's printed rule forbids a cut-down larger picture while its digital rule requires at least 600 × 750 px and says not to crop—one generic export could not honour both.

## Product flow

1. **Capture or import.** A custom `AVCaptureSession` camera evaluates background, crown contrast and framing before enabling its shutter. Library images go through the same crop step.
2. **Review one crop.** A face-aware starting crop is adjustable with pan, zoom, quarter-turn rotation, reset and auto framing. The original stays in memory so users can return from analysis and edit it. Only the accepted crop feeds diagnosis and export; accepting a new crop resets its review.
3. **Diagnose the prepared pixels.** Vision supplies face geometry; pixel analysis supplies background, shadow and glare signals. Findings are `pass`, `fail` or `review`. White/off-white screening is separate from uniformity; unknown crown measurements and ambiguous natural edges remain unresolved.
4. **Confirm human checks.** Expression, glasses/eye visibility, recency and original-source status require explicit visual confirmation. They update the cached diagnosis without rerunning Vision.
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
- runs unit and XCUITest suites and uploads `.xcresult`, logs, portrait diagnostics and screenshots;
- requires no skipped tests or expected failures for a successful unit gate;
- uses the canonical local StoreKit configuration in the test bundles for purchase, restore, cancellation, pending approval and refund checks;
- compiles an unsigned arm64 Release device build;
- audits the built bundle for the icon, launch symbol, privacy manifest, usage descriptions and absence of DEBUG unlock strings.

## Release status

The app is undergoing a correctness and interaction redesign. Use the Actions result for the exact commit as build/test evidence; do not infer camera reliability, issuer acceptance or live App Store product availability from a green simulator run. Local StoreKit Test transactions are simulated and never charge real money. Signing, the live App Store Connect product, hosted privacy/support URLs and submission remain release steps documented in [`docs/RELEASE.md`](docs/RELEASE.md).

The measurement engine labels app-selected thresholds separately from issuer rules. It does not promise approval, and the final decision always belongs to the issuing authority. Physical-camera and printer calibration still require real-device QA, as recorded in [`docs/MANUAL-QA.md`](docs/MANUAL-QA.md).

The baseline gap analysis that drove this pass is in [`docs/PRODUCTION-AUDIT.md`](docs/PRODUCTION-AUDIT.md). `docs/SPEC.md` and `docs/BUILD-CONTRACT.md` are retained as historical research artifacts; the current scope is defined by this README and the corpus.

The October 25 repair and design changes are recorded in [`docs/IMPROVEMENTS-2026-10-25.md`](docs/IMPROVEMENTS-2026-10-25.md).
