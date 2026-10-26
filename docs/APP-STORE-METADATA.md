# App Store metadata

Ready-to-adapt copy for App Store Connect. Character counts are checked against
Apple's limits at the time of writing; confirm them in App Store Connect before
saving.

**Submission still requires account-owner work** (signing, product records,
hosted URLs, device QA). A green CI run proves compilation and the repository's
own tests, not App Store acceptance, printer fidelity or camera behaviour on a
physical iPhone.

## Product page

- **Name:** PassportProof
- **Subtitle:** Passport photo check & export (30 characters)
- **Primary category:** Utilities
- **Age rating:** 4+
- **Price:** Free with two in-app purchases

### Promotional text (170 characters)

> Check your passport or visa photo before you submit it. Exact print sheets and portal-ready files for US, Canadian and German documents. On-device. No account.

### Description

> **A more careful passport photo, before you submit.**
>
> PassportProof guides you through preparing a passport or visa photo and gives
> you a file in the exact format the application asks for.
>
> **Covered documents**
>
> • United States passport — 2 × 2 in print sheet, head 25–35 mm
> • US visa and DV Lottery — 600 × 600 JPEG, under 240 kB
> • Canada passport — 50 × 70 mm print, chin to crown 31–36 mm
> • German Schengen visa — 35 × 45 mm print, face 32–36 mm
>
> Every workflow carries the issuing authority's own figures and the date they
> were checked, with a link to the official page.
>
> **Framing you can trust, honestly labelled**
>
> When on-device face detection is reliable, PassportProof measures the head,
> eye line and centring against the selected document. When it is not, you can
> place four framing guides on the photo yourself and the same published ranges
> are checked exactly. Manually framed results are always labelled as such —
> they never masquerade as an automatic pass.
>
> Expression, glasses, recency and originality need your own confirmation, and
> failed objective checks still block export.
>
> **Print it right**
>
> Print sheets are real PDFs at true physical size, laid out for 4 × 6, 5 × 7 or
> US Letter paper with as many copies as actually fit. A free calibration page
> lets you confirm your printer is not scaling the page before you spend
> anything.
>
> **Pay once, or pay for one**
>
> Checking your photo is free. Exporting costs either one small single-export
> credit or a one-time unlimited purchase — no subscription, ever.
>
> **Private by design**
>
> No account, no analytics, no photo upload. Your photo is processed on device
> and the temporary share file is deleted when sharing finishes.
>
> PassportProof is independent and not affiliated with any government. It
> provides informational checks only; the issuing authority always makes the
> final decision.

### Keywords (98 characters)

`passport photo,visa photo,id photo,2x2 photo,photo check,print sheet,dv lottery,canada`

### What's new in 1.1.0

> Canadian passport and German Schengen visa workflows, true-size print grids
> for non-US formats, a clearer one-export price alongside the unlimited option,
> and a faster route to framing guides when automatic measurement is unavailable.

## Screenshot captions

1. **A better photo, before you submit.** Private, guided preparation for US, Canadian and German documents.
2. **Keep the original within reach.** Reframe, rotate or cancel without losing the accepted photo.
3. **Know where the numbers come from.** Automatic findings and user-placed guides are never mixed up.
4. **Finish the checks only you can make.** Confirm expression, glasses, recency and originality.
5. **Print at true size, or upload the exact file.** Calibrated sheets and portal-sized JPEGs.

Suggested capture set (all from the current build, iPhone Pro Max simulator or
device, light and dark appearance):

| File | Screen |
|---|---|
| `01-library.png` | Library with the country groups |
| `02-document.png` | Document detail with the output card |
| `03-capture.png` | Capture sources |
| `04-review.png` | Photo review with findings |
| `05-manual.png` | Framing guides |
| `06-print.png` | Print preview |
| `07-export.png` | Export readiness |

CI uploads the raw `simulator-screenshots` artifact from every run; crop and
caption them outside the repository. Do not ship a screenshot that shows the
debug build's demonstration unlock.

## App Review notes

> PassportProof has no account or sign-in. On launch, choose a document — for
> example US Passport or US Visa — then **Take or choose a photo**.
>
> The simulator has no camera, so use **Import a photo** and select a clear,
> front-facing original. Adjust the crop and continue to the photo review.
>
> If the review reports that automatic measurement is unavailable, tap
> **Place framing guides**, position the four guides on the actual features and
> switch on all four attestations. Then complete the four ordinary visual
> confirmations. Both the review and the export screen label the photo
> **Manually framed**.
>
> Export uses one of two in-app purchases:
> `com.passportproof.app.single-export` (consumable, one export) or
> `com.passportproof.app.unlock` (non-consumable, unlimited, restorable). The
> free calibration page is available without purchase.
>
> The app is an informational tool and does not promise acceptance. All image
> analysis happens on device; the only network surface is StoreKit and
> user-initiated links to issuer guidance. Privacy details are behind the lock
> icon on the Library screen.
>
> If a product is not available in the sandbox, the Release build fails closed
> and shows no free unlock path.

## URLs and account fields

| Field | Value |
|---|---|
| Privacy policy | Publish [`PRIVACY.md`](PRIVACY.md); URL required |
| Support | Maintained support page with a contact method; URL required |
| Marketing URL | Optional |
| Copyright | Account owner to confirm |
| App Store icon | Generated `icon-1024.png` |
| Review contact | Account owner to provide |
