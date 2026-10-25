# Assessment portrait fixtures

These images are test-only copies of public US Department of State photo examples, retrieved 2026-10-25. They are included only in the unit-test asset catalogue, not in the shipping app.

Source page: https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/photo-examples.html

| Test asset | Official source | Original dimensions | SHA-256 |
|---|---|---|---|
| NeutralPortrait | https://travel.state.gov/content/dam/passports/photo_examples/CROPPED-DSC_0052.jpg/jcr:content/renditions/original | 220 x 220 | 5fdbf976d2b92b41482b504d73f1c1107fcba5a73c4ad123bcb8525c5b576aa2 |
| BlueBackgroundPortrait | https://travel.state.gov/content/dam/passports/photo_examples/background_blue.jpg/jcr:content/renditions/original | 220 x 220 | 7c26af397f597749f507f994241ef6eb9313f786df750ad9f8168b502834e86d |
| WhiteBackgroundPortrait | https://travel.state.gov/content/dam/passports/photo_examples/_MG_3329_good.png/jcr:content/renditions/original | 200 x 200 | 32ecf3abc9cbeac19eedb25f105a61dad8ea8ec3e6289aa860088b05277b809c |

## Interpretation

The webpage uses these to illustrate expression and background requirements. The downloaded example copies are smaller than the app's 600-pixel output requirement. They are not full-resolution submission fixtures: a resolution failure is expected and does not establish a false rejection.

The diagnostic tests exercise real Vision landmark detection and record the production analyzer's individual findings. The automatic-crop test adds a white border around unchanged portrait pixels to provide room for the algorithm to position its crop. This is a controlled geometry experiment, not an exported applicant photograph.

Uniform-background fixtures are generated in code and isolate the background rule with an explicit subject box. They do not claim successful human face recognition or whole-photo approval.

Known defects use strict XCTest expected-failure assertions. A green CI result with expected failures means those defects were reproduced, not fixed; an unexpectedly passing regression must be reviewed and its expected-failure marker removed. None of these tests measures issuer acceptance rates, fairness across populations, live camera reliability, real StoreKit purchases, or physical print accuracy.
