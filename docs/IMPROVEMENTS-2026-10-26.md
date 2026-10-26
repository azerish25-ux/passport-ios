# PassportProof — October 26 pass: a pipeline that can be trusted, and a product that can be sold

## Why this pass happened

The application code was not the main problem. Three things were:

1. **The pipeline was red and could not say why.** Runs reported only
   "Process completed with exit code 65". Every failure needed a `.xcresult`
   download to diagnose, so failures stayed open across commits and a green
   build could not be distinguished from an untested one.
2. **The gating unit tests asserted a third-party behaviour that is broken on
   the build machine.** Vision landmark accuracy reproduces as wrong on every
   iOS Simulator tried (arm64 and Intel, iOS 18.5 and 26.2, several models) and
   is stable on native macOS. No application change can make that green.
3. **The product could only sell to one country at one price.** Three US
   workflows and a single $17.99 non-consumable.

This pass fixes all three, and records what is still not proven.

## 1. CI can now explain itself

`Tools/ci_report.py` parses each `xcodebuild` log and publishes:

- one workflow annotation per distinct compiler error, with file and line;
- one per failing XCTest case;
- a per-step Markdown digest;
- a fallback that names any line mentioning a build failure when no structured
  error matches.

The first version of the script required `file:line: error:` and therefore
missed every Swift error, which emits `file:line:column: error:`. A run reported
"no failure detail" while the app did not compile. That is fixed, and the
workflow no longer hides build output behind `-quiet`.

Raw logs are also kept as artifacts for 14 days.

**Proof that it works:** the next run reported
`PassportProof/Features/Export/ExportView.swift:21: cannot infer key path type
from context` — a missing `import StoreKit` for
`EnvironmentValues.requestReview`. That is a defect this repository could not
have found by reading the code, and it was fixed in one cycle.

## 2. The gates now test this app, not the host

| Gate | Before | After |
|---|---|---|
| Unit | Failed on Simulator landmark accuracy | Asserts the application contract |
| UI | 500 lines of viewport arithmetic, hand-dragged sliders, PhotoKit virtual grid | Seeded original, outcome assertions |
| Vision accuracy | Blocked every commit | `Isolated Vision diagnostic` workflow |

New gating coverage:

- `CatalogueContractTests` — aspect consistency between millimetres and pixels,
  head ranges inside the photo, share/percent agreement, https sources,
  verification dates, changelog presence, grouping completeness, print grid
  counts and true physical size, applicability of optional rules, and that a
  background failure quotes this document's own requirement.
- `PortraitAssessmentTests` — the analysed rule set per document, that missing
  geometry can never become a confident measurement or a fabricated background,
  crop bounds and aspect, and the JPEG byte ceiling on real photographic input.

The strict photographic measurement is not deleted. It lives where it can run
and fail visibly: `Tools/VisionProbe.swift` and
`.github/workflows/vision-probe.yml`, whose recorded results are in
[`IMPROVEMENTS-2026-10-25.md`](IMPROVEMENTS-2026-10-25.md).

## 3. The catalogue covers more than the United States

| Document | Size | Head | Recency | Source |
|---|---|---|---|---|
| Canada passport | 50 × 70 mm print | 31–36 mm chin to crown | 6 months | IRCC |
| German Schengen visa | 35 × 45 mm print | 32–36 mm face | 3 months | German Foreign Office |

Both are appended so existing document indices, tests and saves keep their
meaning. The library is grouped by country, derived from the corpus rather than
maintained as a second list.

Deliberately not added: the UK (printed cream/light-grey background conflicts
with its digital rules), Canada's digital renewal (minimum file size and a 3:2
frame), Indian and Chinese workflows where the head-height rule could not be
read from an official source. Approximating those would have been worse than
omitting them.

## 4. Print grids are true size

Grid counts were hardcoded per paper, which only ever described a 2 × 2 inch
cell. A 35 × 45 mm or 50 × 70 mm photo would have been scaled up to fill the
page — a physically wrong photo, which is the one failure this app exists to
prevent.

`PrintPlan` now derives columns and rows from the document's real size and the
paper's real margins and gutters, with an epsilon so binary rounding cannot turn
two columns into one. It reproduces the designed counts exactly for US photos
(4 / 6 / 12 / 20) and prints every other format at true scale. The calibration
page now draws one cell at the selected document's size instead of a fixed 2-inch
square.

## 5. Pricing has a ladder instead of a single wall

| Product | Type | Fallback price | Restorable |
|---|---|---|---|
| `com.passportproof.app.single-export` | Consumable | $3.99 | No |
| `com.passportproof.app.unlock` | Non-consumable | $7.99 | Yes |

- A credit is granted only from a **verified** transaction, and de-duplicated by
  transaction ID because Apple can deliver the same finished transaction twice.
- A credit is spent only when the share sheet reports a **completed** activity,
  so dismissing it costs nothing.
- The store screen states that a single export is device-local and cannot be
  restored, rather than implying it is permanent.
- The paywall gained an outlined secondary tier, a trust row, a credit balance
  and copy that names exactly what the next tap costs.
- Launching `refresh()` still checks local verified entitlements before the
  network, so a purchased customer is never downgraded by a connection failure.

## 6. Fewer dead ends

- When automatic measurement is unavailable, the review screen now says
  **"Check the framing yourself"**, explains that the same published ranges are
  checked exactly, and offers one pinned primary action —
  **"Place framing guides"** — instead of two competing copies of it.
- The framing-guide editor's suggested positions are valid by construction for
  every document, and still grant nothing until the four attestations are
  switched on.
- A success haptic fires when a file is actually staged.
- The App Store review prompt appears only after a completed, paid export —
  never after a failure or the free calibration page.

## 7. Honest self-assessment

Worked, verified by CI in this pass:

- compiler diagnostics reach the run without a `.xcresult` download;
- the app compiles for the Simulator and for an unsigned arm64 device build.

Verified by CI after this pass (see the run for the exact commit):

- gating unit and UI suites.

Not established, and not claimed:

- Vision landmark accuracy on a physical iPhone;
- camera gate behaviour, printer scaling, App Store review, ranking or revenue;
- the consumable purchase flow end to end in a sandbox account — the local
  StoreKit tests cover the unlimited product, and the credit path needs the
  sandbox pass described in [`RELEASE.md`](RELEASE.md).

Known risks introduced by this pass:

- **The consumable credit is the most delicate new code.** Double-granting is
  guarded by transaction ID, but only a sandbox account test can prove it.
- **UI tests now seed a synthetic original.** They prove the crop, manual
  framing, review and export contracts; they no longer prove that a real
  photograph from the picker flows through unchanged. One test still opens the
  real picker to prove the import path is wired.
- **Two new workflows carry rules from single official pages.** Their sources
  and dates are in the corpus; they have not been reviewed by anyone else.
- **The German figures are the German Schengen profile**, not a claim that every
  member state applies identical details.
