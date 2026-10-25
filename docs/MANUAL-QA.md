# Manual QA — device, purchase and print checks

CI proves that the project compiles, that logic/imaging tests pass, that the UI
smoke tests can navigate the simulator, and that the Release bundle excludes the
DEBUG unlock. It cannot prove camera behavior, printer fidelity, sandbox
purchases, VoiceOver usability or App Review acceptance.

Run this checklist on a current iPhone with iOS 17 or later before submission.

## 1. Camera permission and live gate

1. Fresh install. Open a workflow → **Use live camera**.
2. Deny permission. Confirm the recovery card appears and **Open Settings**
   returns to a working app.
3. Re-enable permission in Settings and reopen the camera.
4. Point at a busy, uneven background. Confirm the shutter is disabled and the
   message names the problem.
5. Move to a plain wall with even light, one face in frame, shoulders visible.
   Confirm the shutter enables only when the live gate reports ready.
6. Capture. Confirm the resulting image is portrait-oriented and the crop editor
   opens without rotation artifacts.
7. Rotate the device; the app intentionally supports portrait only.

## 2. Crop and measurement consistency

1. Choose an asymmetric portrait from the library. Adjust zoom and pan.
2. Accept the crop and inspect the overlay. Crown must be above chin; eye line
   must lie between them.
3. Confirm the dimensions shown for the measured crop are the same pixels used
   in export.
4. Zoom until the crop is below 600 × 600 px. Confirm **Crop resolution** fails
   and export is blocked.
5. Choose a photo with no face. Confirm findings say review/fail honestly and
   never report a confident pass.

## 3. Visual review and export policy

1. Confirm all four visual checks. Their rows should update immediately without
   a new “measuring” pass.
2. Turn off one confirmation. Export must become unavailable.
3. Produce a failed measured rule. Confirm **Export anyway** no longer exists.
4. Return, retake, and confirm the prior diagnosis cannot overwrite the new
   photo.
5. For a clean photo with a remaining unresolved crown/glare check, confirm the
   export explanation appears and only continues after acknowledgement.

## 4. StoreKit sandbox

Use a sandbox Apple Account on a development build:

1. Purchase the non-consumable. Confirm the app unlocks only after verified
   StoreKit success.
2. Cancel a purchase. Confirm no unlock and no false error state.
3. Use Ask to Buy / pending. Confirm the pending message and later restore.
4. Restore on a second install. Confirm entitlement recovers.
5. Revoke/refund the purchase through the sandbox flow where possible, relaunch,
   and confirm entitlement is recomputed rather than cached forever.
6. Launch purchased while offline. Confirm StoreKit current entitlements still
   unlock export.
7. Inspect a Release build. No prototype/debug unlock UI may exist.

## 5. Privacy and lifecycle

1. Enter the app switcher with a photo loaded. Confirm the privacy cover hides
   the photo.
2. Share an export, cancel the share sheet, then inspect the app's temporary
   directory. The `passportproof-*` file must be gone.
3. Complete a session, force-quit, relaunch, and inspect the app container. No
   photograph should persist.
4. Use Airplane mode: library, import, crop, diagnosis, visual checks,
   calibration and export should work. Only a new StoreKit purchase should be
   unavailable.
5. Confirm issuer links open only after a tap and contain no session/photo data.

## 6. Print calibration

1. Export the calibration page for 4×6, 5×7 and Letter layouts.
2. Print at **100% / actual size**, not fit-to-page.
3. Measure the 2.000 in / 50.8 mm square and the millimetre ruler with a physical
   ruler.
4. Print the photo sheet and measure an individual cell. It must remain the
   document's exact physical size.
5. Repeat on at least an inkjet and a laser printer. Record the results; printer
   scaling is not something the PDF can force.

## 7. Accessibility and presentation

1. Test Dynamic Type at AX1 and AX5. No essential value or action may clip;
   cards should grow vertically.
2. Turn on Reduce Motion. Finding rows must not slide; opacity changes are
   acceptable.
3. Complete the main flow with VoiceOver. Finding rows must announce status,
   title, measured value, required range, expansion state and source.
4. Verify the crop editor's adjustable slider and custom “Move crop” actions.
5. Check light and dark appearance for contrast, especially status washes,
   secondary copy and camera overlays.
6. Test iPhone SE-class width and an iPad. Content should remain readable and
   centred rather than stretching edge to edge.
7. Take final App Store screenshots from a current 6.9-inch simulator/device.

## 8. Known external gaps

- A public privacy-policy URL and support page must be hosted outside this repo.
- Signing, TestFlight processing and App Review require the Apple Developer
  account.
- Expression, glasses, recency and source-originality are user confirmations,
  not machine classifiers.
- Background/shadow/centring/crown thresholds are app-selected tolerances and
  are labelled as such in the UI.
