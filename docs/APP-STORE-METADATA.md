# App Store metadata draft

Ready-to-adapt copy for App Store Connect. Character counts are within Apple's
limits at the time of writing; verify them in App Store Connect before saving.

**Submission is blocked pending measurement/device validation.** The current
Simulator automatic-landmark regressions fail. The manual-framing flow must be
described as user-guided formatting, not verified automatic photo compliance.
Do not publish this draft as evidence that those release checks have passed.

## Product page

- **Name:** PassportProof
- **Subtitle:** US passport & visa photo check (30 characters)
- **Primary category:** Utilities
- **Age rating:** 4+
- **Price:** Free with one non-consumable in-app purchase

### Promotional text (170 characters)

> Prepare a US passport, visa or DV photo on your iPhone. Guided framing, clear review notes and correctly sized files. No account or photo upload.

### Description

> **A more careful passport photo, before you submit.**
>
> PassportProof guides you through the practical parts of preparing a US passport,
> visa or DV Lottery photo. Use live camera framing or choose an original image,
> review one crop, and compare it with the document requirements you selected.
>
> **Know what the app can—and cannot—measure.**
>
> Automatic checks use on-device face and image signals when reliable results
> are available. Unavailable measurements remain clearly marked for review.
> You can place framing guides yourself when automatic face measurements are
> unavailable. Dimensions calculated from those guides are labelled manually
> framed; they do not verify the subject or certify the photograph.
>
> Expression, glasses, recency and source originality require your visual
> confirmation. Manual framing also requires you to inspect the guide positions,
> subject, background and lighting. Failed objective checks still block export.
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

> Initial release: guided capture, reversible cropping, clearly labelled manual
> framing, photo-review notes, calibrated print sheets and bounded digital
> exports for three US workflows.

## Screenshot captions

1. **A better photo, before you submit.** Private, guided preparation for supported US documents.
2. **Keep the original within reach.** Reframe, rotate, or cancel without losing the accepted photo.
3. **Know where the numbers come from.** Automatic findings and user-placed framing guides remain clearly distinguished.
4. **Finish the checks only you can make.** Confirm expression, glasses, recency and source originality.
5. **Export the exact photo you reviewed.** Print-ready sheets or portal-sized JPEGs.

## App Review notes

> PassportProof has no account or sign-in. On launch, choose US Passport, US Visa
> or DV Lottery, then choose **Take or choose a photo**.
>
> The simulator has no camera, so use **Import a photo** and select a clear,
> front-facing original. Adjust the crop and tap **Check this photo**. If automatic
> measurements are unavailable, choose **Set framing manually**, place all four
> guides on the actual features and complete the manual review. Then complete
> the ordinary four visual confirmations and review the remaining unverified
> checks. Both analysis and export label the photo **Manually framed**.
> The print calibration sheet is available
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
