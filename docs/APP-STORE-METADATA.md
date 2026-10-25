# App Store metadata draft

Ready-to-adapt copy for App Store Connect. Character counts are within Apple's
limits at the time of writing; verify them in App Store Connect before saving.

## Product page

- **Name:** PassportProof
- **Subtitle:** US passport & visa photo check (30 characters)
- **Primary category:** Utilities
- **Age rating:** 4+
- **Price:** Free with one non-consumable in-app purchase

### Promotional text (170 characters)

> Frame, check and export a cleaner US passport, visa or DV Lottery photo—entirely on your iPhone. Clear measurements, plain-language guidance, no account.

### Description

> **A more careful passport photo, before you submit.**
>
> PassportProof guides you through the practical parts of preparing a US passport,
> visa or DV Lottery photo. Use live camera framing or choose an original image,
> review one precise crop, and see how the photograph measures against the
> document requirements you selected.
>
> **Know what the app can—and cannot—measure.**
>
> Face size, eye line, crop resolution, background variation and lighting signals
> are measured on your device. Requirements that need human judgement, such as
> expression, glasses and recency, appear as an explicit visual checklist. The app
> does not pretend a classifier can settle them.
>
> **Export the photo you actually reviewed.**
>
> For a printed US passport photo, create a calibrated 4 × 6, 5 × 7 or Letter
> sheet at exact physical dimensions. For supported digital workflows, create a
> 600 × 600 sRGB JPEG within the issuer's file-size limit. A free calibration sheet
> helps you check printer scaling before you use the export unlock.
>
> **Private by design.**
>
> No account. No analytics. No photo upload. Your selected crop stays in memory
> while you use the app, and share staging is deleted after the system share sheet
> finishes.
>
> PassportProof is independent and not affiliated with any government. It provides
> informational diagnosis only; the issuing authority always makes the final
> decision.

### Keywords (comma-separated, ≤100 characters)

`passport,photo,visa,dv lottery,photo check,2x2,id photo,crop,travel,background`

### What's new in 1.0.0

> Initial release: guided capture, one reviewed crop, on-device measurements,
> human visual checks, calibrated print sheets and bounded digital exports for
> three US workflows.

## Screenshot captions

1. **A better photo, before you submit.** Private, guided preparation for supported US documents.
2. **Frame it with confidence.** Live guidance and a shutter that waits for a usable frame.
3. **See what was measured.** Clear pass, fail and review results with the required range.
4. **Finish the checks only you can make.** Confirm expression, glasses, recency and source originality.
5. **Export the exact photo you reviewed.** Print-ready sheets or portal-sized JPEGs.

## App Review notes

> PassportProof has no account or sign-in. On launch, choose US Passport, US Visa
> or DV Lottery, then choose **Measure a photo**.
>
> The simulator has no camera, so use **Choose from library** and select any clear
> portrait photo. Adjust the crop and tap **Check this photo**. Complete the four
> visual confirmations to enable export. The print calibration sheet is available
> without purchase; print/digital export uses one non-consumable in-app purchase
> (`com.passportproof.app.unlock`).
>
> The app is an informational measurement tool, not a government service, and it
> does not promise acceptance. All image analysis is on device. The only network
> surface is Apple StoreKit and user-initiated issuer guidance links. Privacy
> details are available from the lock icon on the Library screen.
>
> If the sandbox product is not available during review, the Release build
> intentionally fails closed and shows no free unlock path.

## URLs and account fields

| Field | Value |
|---|---|
| Privacy policy | Publish [`PRIVACY.md`](PRIVACY.md); URL required |
| Support | Maintained support page with contact method; URL required |
| Marketing URL | Optional |
| Copyright | Account owner to confirm |
| App Store icon | Generated `icon-1024.png` |
| Review contact | Account owner to provide |
