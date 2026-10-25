# PassportProof — correctness and studio redesign

## Purpose

The simulator assessment found a missing white/off-white background check, a crop formula that could misplace eyes, a camera quality mismatch, and limited verification of the actual customer journey. This pass fixes those issues and rebuilds the capture/review/export experience around a reversible photo session.

## Implemented changes

- Background brightness and colour are screened separately from uniformity. White/off-white controls pass; clearly dark or coloured walls fail; borderline colour stays review. These are app screening tolerances, not official RGB standards.
- The auto crop targets the selected workflow's eye-height band and respects image boundaries. Visa/DV dimensions derive from official digital percentages and include hair; passport head height uses the anatomical estimate.
- Missing crown evidence does not discard located eyes/chin. More than one detected face cannot silently be treated as one applicant. A rectangular background ring cannot prove editing or noncompliance, so ambiguous natural edges require review.
- Camera output and per-shot quality agree. Processing errors allow another shutter attempt. Camera/import decoding bounds working pixels and applies EXIF orientation.
- The uncropped working original, accepted transform and rotation survive in memory. Reopening/cancelling preserves the accepted photo. Accepting a new crop invalidates previous analysis and visual confirmations. Late analysis and another document cannot take ownership of a new crop.
- A unified studio design adds original vector document artwork, scalable editorial type, adaptive surfaces, explicit Capture/Check/Export progress, accessible controls and useful empty/loading/error states.
- Analysis shows the reviewed photo first, offers direct reframing, separates user confirmations from measurement findings, and keeps uncertainty visible.
- Export previews the actual PDF renderer or complete digital crop. A single contextual primary action respects readiness and purchase state. Share files have a dedicated protected temporary directory and cleanup for active, dismissed and abandoned files.
- A single StoreKit configuration is copied only to test bundles. Integration tests exercise production transaction handling. The app shows a purchasable price only when StoreKit metadata is available.

## Lifecycle refinement

Reopening the crop uses the same full-screen workspace as the first edit. A synchronous per-scene privacy window covers app presentations on backgrounding; active sharing is kept usable. The UI suite backgrounds and resumes a draft edit, then verifies its zoom and dimensions survive and cancel preserves the accepted review. This is state-restoration coverage, not proof of every OS app-switcher snapshot.

## Verification contract

GitHub Actions builds the simulator and unsigned device Release app, runs unit tests, and exports real test attachments. A successful repair unit gate requires zero failed, skipped or expected-failure tests. UI tests use a real PhotosPicker input and local StoreKit transactions; no pre-approved PhotoAnalysis or debug entitlement is injected into the main-flow test.

Full-resolution test photograph: [CC0 fixture provenance](../PassportProofTests/ASSESSMENT-FIXTURES.md). Tests are functional regression evidence, not an issuer-acceptance or population-accuracy study.

Consult the workflow result for the exact commit. Physical camera capture, printer scaling, live App Store account configuration and issuer acceptance cannot be established by an unsigned simulator run.

## Primary references

- [State Department digital composition](https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/photo-composition-template.html): head including hair 50–69%; eyes 56–69% from bottom.
- [Passport photo guidance](https://travel.state.gov/en/passports/apply/help/photos.html).
- [Passport photograph FAM](https://fam.state.gov/FAM/08FAM/08FAM040201.html): anatomical head reference.
- [Apple photo output maximum quality](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/maxphotoqualityprioritization).
- [Apple StoreKit Test](https://developer.apple.com/documentation/storekittest/sktestsession).
