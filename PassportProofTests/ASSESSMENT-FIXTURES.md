# Assessment portrait fixtures

These images are test-only photographic fixtures retrieved 2026-10-25. The first three are public US Department of State examples; the full-resolution portrait is an independently published CC0 photograph. They are included in test resources, not the Release app.

Source page: https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/photo-examples.html

| Test asset | Official source | Original dimensions | SHA-256 |
|---|---|---|---|
| NeutralPortrait | https://travel.state.gov/content/dam/passports/photo_examples/CROPPED-DSC_0052.jpg/jcr:content/renditions/original | 220 x 220 | 5fdbf976d2b92b41482b504d73f1c1107fcba5a73c4ad123bcb8525c5b576aa2 |
| BlueBackgroundPortrait | https://travel.state.gov/content/dam/passports/photo_examples/background_blue.jpg/jcr:content/renditions/original | 220 x 220 | 7c26af397f597749f507f994241ef6eb9313f786df750ad9f8168b502834e86d |
| WhiteBackgroundPortrait | https://travel.state.gov/content/dam/passports/photo_examples/_MG_3329_good.png/jcr:content/renditions/original | 200 x 200 | 32ecf3abc9cbeac19eedb25f105a61dad8ea8ec3e6289aa860088b05277b809c |
| FullResolutionPortrait | https://commons.wikimedia.org/wiki/File:Passport_Pic.jpg | 1062 x 1210 | d197c134f85361311e37ad5bc68ec24abb9951ec93f01702020af2ac2c9471b5 |

The full-resolution file is **Passport Pic.jpg**, author **AnshudeepMaitra**, published under **CC0 1.0 Universal**. Original bytes: https://upload.wikimedia.org/wikipedia/commons/7/71/Passport_Pic.jpg. The downloaded image has not been retouched, upscaled, or relabeled as government-approved. It provides a sufficiently resolved real face for testing; it is not an acceptance benchmark or an applicant's submission.

## Interpretation

The webpage uses these to illustrate expression and background requirements. The downloaded example copies are smaller than the app's 600-pixel output requirement. They are not full-resolution submission fixtures: a resolution failure is expected and does not establish a false rejection.

The diagnostic tests exercise real Vision landmark detection and record the production analyzer's individual findings. The automatic-crop test adds a white border around unchanged portrait pixels to provide room for the algorithm to position its crop. This is a controlled geometry experiment, not an exported applicant photograph.

The 200–220 px illustrations are not assumed to yield usable app geometry. Diagnostics record a separate raw Vision face count alongside the app's result, distinguishing a detected candidate from a face that passes the app's geometry guards. A missing result must produce unresolved geometry-dependent checks. The crop probe tries the full-resolution portrait first, followed by the three small illustrations. It now fails if none establishes measurable, unconstrained geometry; an unexercised regression cannot silently become green. Rejected candidates and the selected candidate remain in the log and attachments. Deterministic source-landmark tests independently verify the crop's placement and boundary behavior.

Uniform-background fixtures are generated in code and isolate the background rule with an explicit subject box. They do not claim successful human face recognition or whole-photo approval.

The background regression tests now require white/off-white to pass, clearly blue/dark backgrounds to fail, and a borderline gray to require review. They no longer use expected-failure markers. None of these photo tests measures issuer acceptance rates, fairness across populations, physical camera reliability, real-money purchases, or physical print accuracy.
