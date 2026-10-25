# PassportProof

[![iOS Build](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml/badge.svg)](https://github.com/azerish25-ux/passport-ios/actions/workflows/ios-build.yml)

PassportProof is a native SwiftUI photo workflow for US passport, visa and DV Lottery applications. It guides capture, diagnoses the prepared photograph against published issuer requirements, asks for the visual checks software cannot prove, and exports the exact reviewed crop as a print sheet or portal-ready JPEG.

Analysis and export happen on device. There is no account, analytics SDK, application backend or photo upload.

## Supported workflows

| Workflow | Output | Geometry | Head height | Other checks |
|---|---|---|---|---|
| US Passport | Printed sheet | 2 × 2 in, 600 × 600 px at 300 DPI | 25–35 mm | 6-month recency, background, expression, glasses |
| US Visa | Digital upload | 600 × 600 JPEG, ≤ 240 kB | 25.4–34.9 mm, 50–69% of frame | Eye line 28–35 mm, 6-month recency |
| DV Lottery | Digital upload | 600 × 600 JPEG, ≤ 240 kB | 25.4–34.9 mm, 50–69% of frame | Eye line 28–35 mm, 6-month recency |

The catalogue deliberately contains only complete workflows. The earlier UK entry was removed because GOV.UK's printed rule forbids a cut-down larger picture while its digital rule requires at least 600 × 750 px and says not to crop—one generic export could not honour both.

## Product flow

1. **Capture or import.** A custom `AVCaptureSession` camera evaluates background, crown contrast and framing before enabling its shutter. Library images go through the same crop step.
2. **Review one crop.** A face-aware starting crop is user-adjustable with pan and zoom. The accepted crop becomes the only image used for preview, diagnosis, print and digital export.
3. **Diagnose the prepared pixels.** Vision supplies face geometry; pixel analysis supplies background, shadow and glare signals. Findings are `pass`, `fail` or `review`—never a false binary.
4. **Confirm human checks.** Expression, glasses/eye visibility, recency and original-source status require explicit visual confirmation. They update the cached diagnosis without rerunning Vision.
5. **Export safely.** Failed applicable checks block export. Digital files are compressed within the issuer's byte ceiling, and print sheets carry exact page geometry plus a free calibration page. Share staging is deleted when the share completes.

## Privacy

- Photos are held in memory for the current session and are never saved to Photos, an app cache or a database.
- No tracking, advertising identifier, analytics or remote configuration.
- `PrivacyInfo.xcprivacy` declares no collected data and no tracking.
- StoreKit is the only purchase surface and uses Apple's network services.
- An opaque privacy cover hides session photos in the app switcher.
- In-app disclosure lives at **Library → Privacy**.

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
PassportProofUITests/  simulator navigation, privacy and screenshot smoke tests
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
- discovers an available iPhone simulator at runtime;
- runs unit and XCUITest suites and uploads the `.xcresult`, log and screenshots;
- compiles an unsigned arm64 Release device build;
- audits the built bundle for the icon, launch symbol, privacy manifest, usage descriptions and absence of DEBUG unlock strings.

## Release status

The repository is a hardened release candidate, not a signed App Store submission. The code-side requirements are implemented and verified in CI. Signing credentials, the App Store Connect record, the in-app-purchase product, metadata, hosted privacy/support URLs and final review remain account-owner steps documented in [`docs/RELEASE.md`](docs/RELEASE.md).

The measurement engine labels app-selected thresholds separately from issuer rules. It does not promise approval, and the final decision always belongs to the issuing authority. Physical-camera and printer calibration still require real-device QA, as recorded in [`docs/MANUAL-QA.md`](docs/MANUAL-QA.md).

The baseline gap analysis that drove this pass is in [`docs/PRODUCTION-AUDIT.md`](docs/PRODUCTION-AUDIT.md). `docs/SPEC.md` and `docs/BUILD-CONTRACT.md` are retained as historical research artifacts; the current scope is defined by this README and the corpus.
