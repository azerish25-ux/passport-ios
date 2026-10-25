# PassportProof — production quality audit

**Baseline:** `893b80d` on `main`  
**Audit date:** 24 October 2026  
**Verification baseline:** GitHub Actions run `40145475669` succeeded on macOS 15: simulator build, 23 unit tests, and unsigned Release device build. This proves compilation and the existing tests, not product correctness or App Store acceptance.

## Remediation status

The audit above is the baseline, not the current state. The production pass
addressed the code-side findings:

| Baseline finding | Current implementation |
|---|---|
| Analysis and export used different pixels | One aspect-locked, user-reviewed crop feeds preview, Vision, print and JPEG; a 2048 px analysis bound preserves output quality without processing a 12 MP source |
| Camera gate ran after the shutter | Custom `AVCaptureSession` preview analyses the document-aspect frame and disables the shutter until framing/background checks pass |
| Release prototype unlock | Bypass and its UI are inside `#if DEBUG`; CI audits the compiled Release binary for its strings |
| Contradictory UK/output rules | Launch scope narrowed to three complete US workflows with output-specific rules and byte limits |
| Failed checks could export | Export requires a matching face geometry, no failed applicable rule, all four visual confirmations and StoreKit entitlement |
| Stale async results/lifecycle | Session revisions guard analysis; crop/export tasks are cancellable; staging is owned and removed on share completion |
| Entitlement accumulated forever | Verified entitlements are recomputed offline first, live transaction updates are observed, pending/restore states are explicit |
| Dense, fixed-type UI and weak accessibility | Card-based hierarchy, semantic Dynamic Type, 4.5:1 contrast test, labelled controls, hidden decorative overlays, Reduce Motion, large-text UI smoke test |
| Shallow verification | Unit coverage expanded for crop/export consistency, byte ceilings, applicable rules, future EXIF dates, session export gating and contrast; XCUITest covers library, privacy, capture entry and unlock with screenshots |

The current release status and external residuals are tracked in
[`RELEASE.md`](RELEASE.md). A CI link and exact test count are added after the
final verified run; no signed/TestFlight/App Review claim is made here.

## Executive finding

The repository has a thoughtful measurement model and a coherent visual seed, but it is still a prototype rather than a submission candidate. The highest-risk defect is architectural: the image that is measured is not the image that is exported. Release claims must remain scoped to build configuration until the issues below are resolved and device QA is complete.

## P0 — correctness and submission blockers

### 1. Analysis and export use different images

- **Evidence:** `Features/Capture/CaptureView.swift` adopts the original image; `Features/Analysis/AnalysisView.swift` measures `session.cgImage`; `Core/Export/DigitalExport.swift` later applies an independent centre crop.
- **Impact:** head size, eye line, centring, background, and resolution findings can describe pixels that are absent from the delivered file.
- **Required change:** one explicit crop transform must produce the session image used by preview, analysis, print, and digital export. A user-adjustable crop must preserve aspect ratio and never upscale beyond the chosen export policy.

### 2. The camera gate runs after the system shutter

- **Evidence:** `Features/Capture/CameraPicker.swift` uses `UIImagePickerController`; `Features/Capture/CaptureView.swift` evaluates the returned still.
- **Impact:** the acceptance requirement for pre-capture background and framing enforcement is not met.
- **Required change:** replace the picker with an `AVCaptureSession` preview, throttled frame analysis, visible gate state, and a shutter that cannot fire while the gate is failing. Preserve a clear permission-denied recovery path.

### 3. Prototype purchase bypass is compiled into Release

- **Evidence:** `Core/Store/EntitlementStore.swift` and `Features/Unlock/UnlockView.swift` expose `unlockForPrototype()` without a compilation-condition boundary.
- **Impact:** production users could receive paid functionality without an App Store transaction.
- **Required change:** constrain the bypass to DEBUG, omit its UI in Release, observe transaction updates, and recompute rather than only accumulate entitlement state.

### 4. Document rules and output rules are not aligned

Issuer guidance checked on 24 October 2026 shows that a single generic crop/export policy is invalid:

- UK printed photos must be 35 × 45 mm with a 29–34 mm head, must be taken in the last month, and **must not be a cut-down version of a larger picture** ([GOV.UK printed photos](https://www.gov.uk/photos-for-passports/photo-requirements)).
- UK digital photos have different pixel, file-size, recency, and no-crop rules ([GOV.UK digital photos](https://www.gov.uk/photos-for-passports)).
- US visa digital images must be square, 600–1200 px, JPEG/sRGB, and no more than 240 kB ([Digital image requirements](https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos/digital-image-requirements.html)).
- DV digital images are 600 × 600 px and no more than 240 kB ([Photo requirements](https://travel.state.gov/content/travel/en/us-visas/visa-information-resources/photos.html)).
- The current US printed-passport page states a 25–35 mm head and separates printed-photo guidance from online digital uploads ([Passport photos](https://travel.state.gov/content/travel/en/passports/how-apply/photos.html)).

**Required change:** narrow the launch corpus to workflows that can be implemented faithfully; model output type, recency, pixel constraints, and file-size limits per document; do not advertise unsupported or contradictory outputs.

## P1 — core product gaps

### 5. Export policy contradicts the diagnosis

- `AnalysisView` offers **Export anyway** after failures although the engineering contract requires failed checks to force a retake.
- Rules that do not apply to a document are emitted as `cannotVerify`, so an otherwise clean result can never read as complete.
- Expression, glasses, and original-image manipulation receive no meaningful user review workflow; glasses can report `pass` without detecting glasses.
- Future EXIF dates produce a negative age that passes.

**Required change:** filter non-applicable rules, add explicit visual confirmations for checks that cannot be automated honestly, block export on failed applicable checks, and handle missing/future metadata without guessing.

### 6. Export and staging are incomplete

- `PrintSheetRenderer` draws the uncropped original into each cell while `DigitalExport` centre-crops, so print and digital outputs differ.
- JPEG quality is fixed and the 240 kB limit is not checked.
- Export runs synchronously on the UI actor and share staging cleanup is tied to view disappearance rather than share completion.

**Required change:** render both outputs from the same prepared image, enforce document-specific byte limits with bounded compression, move work off the main actor, and delete only files owned by the active share when it finishes.

## P1 — premium UI and accessibility gaps

- The library presents eight empty placeholder slots and repeated prototype warnings instead of a focused, production-scope catalogue.
- Dense uppercase/monospaced copy, technical geometry notes, and full-bleed rule lists overwhelm the primary task.
- `Theme.swift` uses fixed point sizes; Dynamic Type behaviour is not systematically designed or tested.
- Capture review and export lack polished preview, progress, confirmation, and recovery states.
- `FaceOverlayView` exposes technical measurement axes directly to assistive technology; major flows lack stable accessibility identifiers and UI tests.

**Required change:** retain the precise editorial identity while introducing clear hierarchy, responsive cards, guided steps, human language, scalable type, accessible summaries, Reduce Motion behaviour, and end-to-end UI smoke tests.

## P2 — verification and release gaps

- Existing tests are valuable but heavily logic-focused; there is no UI test target or simulator screenshot evidence.
- PDF tests do not fully verify page/cell geometry and rendered instructions.
- CI builds Release for device but does not exercise the UI or audit the built bundle for DEBUG-only purchase bypasses.
- App Store Connect signing, IAP records, metadata, screenshots, privacy answers, review notes, and real-device/printer QA remain external to the repository and must not be described as completed.

## Strengths to preserve

- On-device processing with no account, analytics, or application backend.
- Three-state findings and explicit measurement provenance.
- Dual crown estimation with a conservative `cannotVerify` outcome.
- Deterministic project generation and dependency-free Apple-framework implementation.
- Existing macOS CI with simulator tests and unsigned Release device compilation.
- A distinctive warm-paper/ink design foundation rather than a generic template.

## Remediation sequence

1. Unify crop/preview/analysis/export and correct the document/output model.
2. Implement live camera capture, meaningful review checks, export policy, and StoreKit hardening.
3. Redesign the complete flow and accessibility layer.
4. Expand unit/UI tests, run macOS/Xcode CI, inspect screenshots, and verify the committed tree.
5. Limit the final readiness claim to evidence; leave signing, App Store Connect, physical camera, and printer checks explicitly assigned to the release owner.
