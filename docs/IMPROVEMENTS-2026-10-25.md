# PassportProof — correctness and studio redesign

## Purpose

The simulator assessment found a missing white/off-white background check, a crop formula that could misplace eyes, a camera quality mismatch, and limited verification of the actual customer journey. This pass fixes those issues and rebuilds the capture/review/export experience around a reversible photo session.

## Implemented changes

- Background brightness and colour are screened separately from uniformity. White/off-white controls pass; clearly dark or coloured walls fail; borderline colour stays review. These are app screening tolerances, not official RGB standards.
- The auto crop targets the selected workflow's eye-height band and respects image boundaries. Visa/DV dimensions derive from official digital percentages and include hair; passport head height uses the anatomical estimate.
- Missing crown evidence does not discard located eyes/chin. More than one detected face cannot silently be treated as one applicant. A rectangular background ring cannot prove editing or noncompliance, so ambiguous natural edges require review.
- The face-region brightness metric retains its existing threshold, but high variation requires visual review. Natural features and beards can create the same signal as uneven illumination; the app no longer presents that metric alone as proof of a cast shadow. Controlled-pixel regressions cover both variation and flat-light controls.
- Camera output and per-shot quality agree. Processing errors allow another shutter attempt. Camera/import decoding bounds working pixels and applies EXIF orientation.
- The uncropped working original, accepted transform and rotation survive in memory. Reopening/cancelling preserves the accepted photo. Accepting a new crop invalidates previous analysis and visual confirmations. Late analysis and another document cannot take ownership of a new crop.
- A unified studio design adds original vector document artwork, scalable editorial type, adaptive surfaces, explicit Capture/Check/Export progress, accessible controls and useful empty/loading/error states.
- Analysis shows the reviewed photo first, offers direct reframing, separates user confirmations from measurement findings, and keeps uncertainty visible.
- Export previews the actual PDF renderer or complete digital crop. A single contextual primary action respects readiness and purchase state. Share files have a dedicated protected temporary directory and cleanup for active, dismissed and abandoned files.
- A single StoreKit configuration is copied only to test bundles. Integration tests exercise production transaction handling. The app shows a purchasable price only when StoreKit metadata is available.

## Lifecycle refinement

Reopening the crop uses the same full-screen workspace as the first edit. A synchronous per-scene privacy window covers app presentations on backgrounding; active sharing is kept usable. The UI suite backgrounds and resumes a draft edit, then verifies its zoom and dimensions survive and cancel preserves the accepted review. This is state-restoration coverage, not proof of every OS app-switcher snapshot.

The app declares `UIRequiresFullScreen` compatibility mode to match its existing restricted iPad orientations and address the device-build orientation warning. Device families and orientation lists are unchanged. This does not promise a literal full-screen presentation: Stage Manager and iPadOS 26 Windowed Apps can display a scaled scene alongside other apps. Apple deprecated this compatibility mode in iPadOS 26; builds using the iOS 27 SDK can resize discretely. The camera remains configured for portrait capture. Landscape camera behavior and resizable iPad workspaces have not been verified; this declaration is an interim compatibility measure, not that validation.

## Vision repeatability

Run `40167034370` exposed inconsistent raw face landmarks across sequential requests on the iOS 26.2 Simulator, including coordinates outside the documented face-normalized range. Run `40168821550` reproduced this with Xcode 26.3 and both explicitly selected CPU and default compute: repeated reads of one observation stayed identical, while new requests drifted. Toolchain alignment and CPU selection did not fix it. This does not establish an Apple-confirmed defect or its cause.

Run `40170019707` also rejected revision 2 / 65 points: its first result was visibly misplaced, and repeated results became invalid. Revision 3 / 65 and 76-point comparisons also drifted, so revision selection alone is not a fix. The CPU override remains removed.

The next checkpoint uses Vision's public `pointsInImage(imageSize:)` API to obtain image-space landmarks and converts their origin and scale once. Production and ordinary portrait diagnostics no longer read the normalized-coordinate accessor. The app validates finite image bounds, required facial regions and a conservative minimum eye-to-chin span before publishing geometry. That span check is an app sanity heuristic, not an issuer threshold or a replacement measurement. Simulator and hardware both use explicit revision 3 / 76 points with system-selected compute. Strict tests require 12 repeated real-photo measurements to stay consistent and inside coarse, independently inspected eye/chin regions; a separate photographic test exercises actual automatic crop placement. The normalized accessor comparison runs last as diagnostic evidence. These changes remain a candidate until the corresponding Actions run passes. No coordinates or analysis results are fabricated, and a physical-device accuracy/performance check remains necessary.

Run `40171387997` rejected that candidate: 57 of 61 unit tests passed, with four photographic measurement failures. Direct image coordinates also drifted before any normalized getter was used, and before/after comparison of that getter did not change the observation. The accessor is therefore not established as the cause. The conservative guard correctly withholds unusable geometry, but this is not a working measurement fix.

`Tools/VisionProbe.swift` and the separate **Isolated Vision diagnostic** workflow remove application code, UIKit, asset catalogues and pixel sampling from the experiment. Each native process decodes the unchanged JPEG using ImageIO and performs 12 strict real-image requests. Independent processes compare the default detection pipeline with documented explicit face-rectangle observations on macOS, iOS 18.5 and iOS 26.2. Every failed check remains a nonzero process/job result, with logs uploaded. These diagnostics do not replace the app's unit/UI gates.

The bounded control results are:

| Target and mode | Requests passing the complete measurement/repeatability checks | Actions evidence |
|---|---:|---|
| Native macOS arm64, revision 3 direct / explicit rectangles | 12/12 in each mode | [40172454108](https://github.com/azerish25-ux/passport-ios/actions/runs/40172454108) |
| iOS 18.5 arm64, revision 3 direct / explicit rectangles | 0/12 in each mode | [40172454108](https://github.com/azerish25-ux/passport-ios/actions/runs/40172454108) |
| iOS 26.2 arm64, revision 3 direct / explicit rectangles | 0/12 in each mode | [40172454108](https://github.com/azerish25-ux/passport-ios/actions/runs/40172454108) |
| iOS 18.5 Intel, revision 3 direct / explicit rectangles | 0/12 in each mode | [40173253252](https://github.com/azerish25-ux/passport-ios/actions/runs/40173253252) |
| iOS 26.2 arm64, modern async API (selected revision 3) | 0/12 | [40173808352](https://github.com/azerish25-ux/passport-ios/actions/runs/40173808352) |
| iOS 26.2 arm64, legacy revision 1 / 65 points | 0/12 | [40173808352](https://github.com/azerish25-ux/passport-ios/actions/runs/40173808352) |

Every mode above compiled and executed. Failed Simulator requests still found exactly one face but produced incorrect or drifting landmarks. There is no supported basis for another speculative runner, compute or API switch. This evidence localizes the reproduced behavior to these Simulator executions; it does not establish an Apple-confirmed root cause or verify a physical iPhone.

## Transparent manual recovery

When automatic geometry is unavailable and no actual rule is failing, the user can place normalized head, chin, eye and centre guides on the accepted photo. The upper reference follows the selected workflow: anatomical skull crown for passport, head including hair for visa/DV. The editor shows calculated dimensions as **From your guides**, validates finite bounds/order and the applicable ranges, and requires explicit guide, face/pose, background/lighting and limitation confirmations.

The separate manual record is bound to the document and accepted-photo revision. It never creates `FaceGeometry`, changes a failed rule to a pass, or supplies a synthetic face box to pixel analysis. A low-resolution crop still blocks export. All ordinary visual confirmations remain required. Accepting a new crop, receiving a new diagnosis or clearing the session removes manual approval; cancelled edits preserve the previous accepted state.

Analysis and export display **Manually framed**, including before the purchase route. Automatic findings remain unresolved and available to review. The guide overlay is only an editing aid and is not rendered into the exported photograph. Unit coverage exercises invalid guides, confirmation requirements, stale records and resolution failures. The UI journey explicitly chooses this manual path using the real photo picker and guide controls; it is not an automatic-analysis success test. The strict photographic automatic regressions remain unchanged and retain their failed status.

The cancellation integration test uses StoreKit Test's supported per-API simulated error. Its older `failureError = .paymentCancelled` setup was unsupported and did not prove a production cancellation defect. Cancellation passed in run `40168821550`; the failure-to-retry scenario instead received an Xcode test-server error after disabling the simulated failure. The retry test restores documented test-server defaults, verifies the simulated error is cleared, and follows the UI's refresh-then-purchase recovery path using the same app store instance and transaction history. All five StoreKit integration tests passed in run `40170019707`, including verified retry. No error is treated as success.

The real Photos picker reached crop and analysis in run `40170019707`. Its accessibility hierarchy exposed a section identifier overriding the four review-toggle identifiers. Section markers now belong to their headings, preserving each actionable control's identity. The same pattern is removed from the export preview. The UI tests retain all individual confirmation and state-preservation assertions.

## Verification contract

GitHub Actions builds the simulator and unsigned device Release app, runs unit tests, and exports real test attachments. A successful repair unit gate requires zero failed, skipped or expected-failure tests. UI tests use a real PhotosPicker input and local StoreKit transactions; no pre-approved PhotoAnalysis or debug entitlement is injected into the main-flow test.

Both jobs explicitly select the preinstalled Xcode 26.3 toolchain on `macos-15` and fail if its verified installation path is absent. The simulator resolver requires an available iPhone runtime matching the selected simulator SDK's major/minor version (currently iOS 26.2), and records SDK, runtime and device details. It does not fall back to an unrelated newer runtime. This replaces the runner's Xcode 16.4 default and aligns verification with Apple's requirement, effective April 28, 2026, to upload apps built with Xcode 26 or later and an iOS 26 or later SDK. The deployment target remains iOS 17. Toolchain alignment does not establish the cause of the earlier Vision inconsistency; repeated CPU/default diagnostics must be evaluated on the selected toolchain.

Full-resolution test photograph: [CC0 fixture provenance](../PassportProofTests/ASSESSMENT-FIXTURES.md). Tests are functional regression evidence, not an issuer-acceptance or population-accuracy study.

Consult the workflow result for the exact commit. Physical camera capture, printer scaling, live App Store account configuration and issuer acceptance cannot be established by an unsigned simulator run.

## Primary references

- [State Department digital composition](https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/photo-composition-template.html): head including hair 50–69%; eyes 56–69% from bottom.
- [Passport photo guidance](https://travel.state.gov/en/passports/apply/help/photos.html).
- [Passport photograph FAM](https://fam.state.gov/FAM/08FAM/08FAM040201.html): anatomical head reference.
- [Apple photo output maximum quality](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/maxphotoqualityprioritization).
- [Apple StoreKit Test](https://developer.apple.com/documentation/storekittest/sktestsession).
- [Apple image-coordinate face landmarks](https://developer.apple.com/documentation/vision/vnfacelandmarkregion2d/pointsinimage(imagesize:)).
- [Apple full-screen compatibility behavior](https://developer.apple.com/documentation/bundleresources/information-property-list/uirequiresfullscreen).
- [Apple TN3192: migrate away from full-screen compatibility mode](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key).
- [GitHub's exact macOS 15 runner software manifest](https://github.com/actions/runner-images/blob/macos-15-arm64/20260907.0337/images/macos/macos-15-arm64-Readme.md): Xcode 26.3 is installed alongside the older default.
- [Apple Xcode SDK and host requirements](https://developer.apple.com/xcode/system-requirements).
- [Apple App Store SDK minimum requirements](https://developer.apple.com/news/upcoming-requirements/?id=04282026a): Xcode 26 and iOS 26 SDK minimum since April 28, 2026.
