# Manual QA — what CI cannot check

CI proves the app compiles for two SDKs and that the pure-logic tests pass. It
cannot prove the app is *correct*, because the three things most likely to be
wrong are all visual or device-dependent. This is the short list; run it on a
simulator before trusting any measurement the app reports.

Everything here is a two-minute check on the Simulator (Xcode 16+, iPhone 16 or
later), except item 4, which needs a printer.

---

## 1. The vertical axis is not flipped — **highest priority**

`FaceAnalyzer` receives Vision points with a bottom-left origin and flips them to
top-down. If that flip is wrong, nothing crashes and nothing fails a test: an
inverted head still has a plausible *magnitude* of head height, so the app would
return a confident pass or fail built on a mirrored measurement. This is the
worst failure mode the product has, because it is silent.

**The check is binary, not numerical.** `FaceOverlayView` draws `crownEnvelopeY`,
`chinY` and `eyeY` straight through as `normalised × containerSize` with no
transform of its own. So:

1. Import any portrait photo with a visible face.
2. Open **Diagnose**.
3. Look at the overlay.

- **Crown line above the chin line, eye line between them** → the flip is correct.
  If the lines are right-way-round but offset from the face, the flip is fine and
  the error is in the landmark points themselves.
- **Crown line below the chin line** → the flip is inverted. Every head-height
  number in the app is mirrored. Fix `topLeftPoints` before anything else.

Do not substitute "the head height looks about right" for this check. It does not
catch the failure.

As a second line of defence, `FaceAnalyzer` now refuses geometry where the eye
line does not fall between 30% and 70% of the way from crown to chin, and reports
`cannot verify` instead. If you see `cannot verify` on a clean, well-lit portrait
with the face filling half the frame, that guard is firing — check the flip.

## 2. The PDF is the right way up

`PrintSheetRenderer` draws a `UIImage` into a PDF page. A rotated sheet still
looks like a sheet until it is next to a ruler.

Print the **calibration sheet** (Export → *Print calibration sheet*, which does
not consume the unlock). It draws a 2.000 in square and a millimetre ruler on a
page with nothing else on it. If the square and the ruler disagree about which
way is up, or the square does not measure 2.000 in, the draw path is wrong.

Then check a real sheet: the photo cells and the "PRINT AT 100% — DO NOT SCALE"
line must share an orientation.

## 3. The capture gate actually blocks the shutter

§6.2's gate exists to guarantee a plain, evenly lit background *before* the
shutter releases. Point the camera at a busy, high-contrast background: the
shutter must be disabled and the gate's message must name what is wrong. Point it
at a plain wall with a face in the band: the shutter must enable.

The Simulator has no camera, so this needs a device. On the Simulator the camera
affordance is disabled with an explanatory line and the photo-library path stays
fully functional — that is expected, not a bug.

## 4. The print geometry survives a real printer

This is the report's number-one unmeasured risk (§6.6), and it is still
unmeasured. Print one sheet on three printers — inkjet, laser, photo kiosk — at
three settings each: 100%/actual size, fit-to-page, borderless. Measure a cell
with a ruler. Anything other than 2.000 in at "100%" means the driver is scaling,
which is exactly why the calibration sheet ships.

## 5. The prohibitions are still honoured

Five minutes with the app, checked against §2.6:

- **No photo storage** — run a full session, force-quit, relaunch, then inspect
  the app container. No image file should exist.
- **No account** — cold launch reaches the library with zero taps.
- **No subscription** — the unlock screen shows one price and one button.
- **No server** — put the device in airplane mode. Capture, diagnose and both
  exports must complete. Only purchase may be unavailable.
- **No approval promise** — read every string. "approved", "guaranteed",
  "official" and "accepted" must not appear as a claim about the user's photo.

## 6. Dynamic Type

Set the largest accessibility text size. Measurement rows must wrap rather than
clip, and the monospaced figures must stay legible. This is not tested anywhere.
