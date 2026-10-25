# PassportProof — Engineering Specification

> **Historical research artifact.** The shipped production scope is defined in
> [`README.md`](../README.md): three complete US workflows with output-specific
> rules. In particular, this document's four-document/UK assumptions, 4×6
> four-up contract and "prototype data" labels no longer describe the app. The
> research reasoning remains here for provenance and audit, not as the current
> product contract.

**Derived from:** `PassportProof-iOS-App-Research-Report.md` v2.0 (24 Oct 2026), `PassportProof-Stress-Test.md`, and `…-v1.0-superseded.md`.
**Governing source:** v2.0. Where v1.0 and v2.0 disagree, v2.0 wins and the disagreement is noted in one line.
**Scope:** the prototype app only. The research concludes the *business* should not be built; that conclusion is out of scope here and does not affect the engineering spec, which v2.0 states is sound (§10, "What survives").
**Every claim below carries a § reference.** Where a figure is labelled in the source it keeps its label: *measured* / *benchmark* / *assumption* / *circular*. Where the documents do not specify something a coder needs, it is marked **GAP** and listed in §10.

---

## 1. The six core features (§2.6)

Verbatim, §2.6: *"Six core features: capture and auto-crop to a chosen country's spec; background compliance diagnosis with reshoot guidance; a pre-export compliance check on head size, eye line, centring, shadow, expression and glasses; print-sheet export at 300 DPI; a digital export sized for the online application portal; a country spec library with a dated changelog."*

| # | Feature (verbatim) | Screen | Behaviour |
|---|---|---|---|
| F1 | capture and auto-crop to a chosen country's spec | **Capture** | Document chosen *before* the camera opens. Live overlay draws the head-height band from the selected document's clause (§6.2). Shutter gated (§6). Auto-crop to the document's aspect ratio on accept; the crop is geometric only — no retouching (§4.3). |
| F2 | background compliance diagnosis with reshoot guidance | **Diagnose** | Reports uniformity as a **threshold test**, not a perceptual one (§2.6, §6.2). Failing region is highlighted and a concrete reshoot instruction is shown. Segmentation is used to *measure*, never to replace (§2.6, §4.3). |
| F3 | a pre-export compliance check on head size, eye line, centring, shadow, expression and glasses | **Check** | Six named checks, each returning `pass` / `fail` / `cannot verify` (§6.2). Runs after crop, before any export. Head size is the only check with a numeric threshold in the source (see §3). |
| F4 | print-sheet export at 300 DPI | **Print** | Layout picker (4×6, 5×7, Letter/A4), exact page box, cut marks where a gutter exists, rendered "print at 100% — do not scale" instruction, calibration sheet offered before the paid export (§6.3, §6.6). |
| F5 | a digital export sized for the online application portal | **Export** | Single file at the document's portal geometry, DPI written as metadata (§6.4, ref 15). Shares out; no upload. |
| F6 | a country spec library with a dated changelog | **Library** | List of covered documents only; per document, every rule with its issuing clause, its date and its source. Explicit "unsupported country" state for everything else (§6.5, §6.8 risk 7). |

Cost basis: F1–F6 plus paywall and QA are 25.7 person-weeks; capture enforcement adds +2.0 and the extra layouts +0.5, for **28.2** (§6.4).

---

## 2. The six prohibitions (§2.6)

Verbatim, §2.6: *"Six prohibitions, phrased as verbs: **do not store photos**; **do not require an account**; **do not ship a subscription**; **do not synthesise a background**; **do not call a server**; **do not promise approval**."*

These are architectural, not stylistic. Each has a visible consequence the prototype must show.

| # | Prohibition | Architectural consequence | How a reviewer verifies it |
|---|---|---|---|
| P1 | do not store photos | Image lives in memory for the session only. No cache directory, no Core Data blob, no Photos write except an explicit user-initiated save. | Kill and relaunch after a full session; app container holds no image. |
| P2 | do not require an account | No sign-in, no onboarding wall, no identity. Also avoids Guideline 5.1.1(v) (§4.6). | Cold launch reaches Capture with zero taps. |
| P3 | do not ship a subscription | Exactly one non-consumable IAP. No auto-renewable product in the StoreKit configuration. Avoids Guideline 3.1.2(a) (§4.6). | StoreKit config contains one product; paywall shows one price. |
| P4 | do not synthesise a background | No generative fill, no inpainting, no background replacement. `VNGeneratePersonSegmentationRequest` may be read for measurement only (§2.6). Forced by 8 FAM 402.1-3(g) (§4.3). | No code path writes pixels behind the subject. |
| P5 | do not call a server | No analytics SDK, no crash reporter with network egress, no remote config. StoreKit is the only network surface, and it is Apple's. Cost of this: no revocation, no refund handling, no cross-device reconciliation beyond StoreKit sync (§6.7). | Airplane-mode run completes every non-purchase flow. |
| P6 | do not promise approval | No "approved", "guaranteed", "official", "accepted", "government-approved". Framing is informational diagnosis (§6.8 risks 1 and 8). The `cannot verify` state (§4) is the visible form of this promise-keeping. | String audit over app and metadata. |

---

## 3. The validator rule set

**16 rules are recoverable from the documents. 7 carry a number; 5 are named with no tolerance; 1 is absent; 3 are binary regulatory constraints.** Every rule below is traceable; nothing is invented.

### 3.1 Rules with a stated threshold

| # | Rule | Measurement | Unit | Pass / fail | Source | Label |
|---|---|---|---|---|---|---|
| R1 | Head height, lower bound | chin → **top of skull** (not top of hair) | mm | ≥ **25.4** (1 in) | §4.5 | measured (unit identity) |
| R2 | Head height, upper bound | same | mm | ≤ **34.9** (1⅜ in) | §4.5 | measured |
| R3 | Head height as share of image | head height ÷ image height | % | **50–69%** of image height; on a 51 mm image = 25.5–35.2 mm | §4.5, §6.1 | measured |
| R4 | Head height in print pixels | at 300 DPI | px | **300–412 px** in a 600×600 cell | §6.2, §6.4 | derived |
| R5 | Background uniformity | residual original-background pixels at the hair edge | px ring | **any** 1–2 px ring fails; there is no perceptual tolerance | §2.6, §6.2 | measured (threshold, not perceptual) |
| R6 | Output resolution | render target | DPI | **300**; 2×2 in cell = **600×600 px**; 4×6 sheet = **1200×1800 px** | §6.2, §6.4 | measured |
| R7 | Photo age | capture date → submission date | months | **≤ 6 months**; older is disqualified | §11 ref 29 | measured (visa documents) |

**The 22 mm vs 25.4 mm contradiction (§4.5) — which clause governs and why.**

The State Department's visa photo page states the head must be *"between 1 inch and 1 3/8 inches (22 mm and 35 mm)"*, and the DV-2025 instructions repeat it (§4.5). The page therefore contains three clauses: an imperial clause (1–1⅜ in), a metric clause (22–35 mm), and a proportion clause (50–69% of image height). They cannot all be right.

- One inch **is** 25.4 mm by definition. So the imperial clause reads 25.4–34.9 mm, and the metric clause's lower bound of 22 mm is **wrong by 3.4 mm** (§4.5).
- The proportion clause adjudicates: **50–69% of a 51 mm image is 25.5–35.2 mm**, which corroborates 25.4/34.9 and refutes 22/35 (§4.5).
- **Governing reading: 25.4–34.9 mm.** The imperial clause plus the proportion clause outvote the metric clause 2:1, and the metric clause is internally inconsistent with a definitional unit identity.

A naive scraper encodes 22 mm and rejects compliant photos. That is the corpus's whole reason for existing (§4.5, §10). **The prototype must encode 25.4 mm and must never evaluate against 22 mm.**

### 3.2 Rules named but not quantified — **GAP**

§2.6 names these as checks; no document gives a tolerance for any of them.

| # | Rule | What the documents say | What a coder needs |
|---|---|---|---|
| R8 | Eye line | named as a check (§2.6); eye line also appears as the input to the second crown estimator (§6.2) | **GAP G2** — no height, band or ratio |
| R9 | Centring | named as a check (§2.6); 8 FAM 402.1-2(5)(a) lets *the Department* re-crop an off-centre face (§4.3) | **GAP G2** — no offset tolerance |
| R10 | Shadow | named as a check (§2.6) | **GAP G2** — no luminance or gradient threshold |
| R11 | Expression | named as a check (§2.6) | **GAP G2** — no classifier, no acceptance set |
| R12 | Glasses | named as a check (§2.6) | **GAP G2** — no glare/rim/frame rule |
| R13 | Headroom | **absent from all three documents** | **GAP G3** — only the 50–69% band (R3) constrains it, indirectly |

### 3.3 Binary regulatory constraints

| # | Rule | Statement | Source |
|---|---|---|---|
| R14 | No facial manipulation | *"Digital manipulation and/or retouching of the facial image on photographs is not acceptable. The use of beauty filters or other photo filter tools… are also not acceptable."* Scoped to **the facial image**, not the photograph. | 8 FAM 402.1-3(g), §4.3 |
| R15 | Plain background required | 8 FAM 402.1-3(e) requires a plain background; the app may **diagnose** against it but may not create one. | §4.3 |
| R16 | Original, unedited photo | The public rule is broader than 3(g): submit *"the original, unedited photo without filters or digital changes."* | §4.3 |

**Interpretive note (not stated in the documents).** 8 FAM 402.1-2(4)(a) and (5)(a) permit resizing and re-cropping, but §4.3 is explicit that these are *"the Department's own post-submission remediation powers over a photo already filed, not a licence to applicants or third-party apps."* The product nevertheless auto-crops (F1), so the prototype treats **geometric crop as permitted** and **any pixel synthesis as forbidden**. This reading is inferred from the feature list; it is not stated. **GAP G7.**
Red-eye removal is separately banned at 8 FAM 402.1-3(h) in v1.0 §4.3. **v2.0 omits 3(h).** v2.0 wins: the prototype must still not remove red-eye, since 3(g) covers the facial image.

---

## 4. The "cannot verify" requirement (§6.2)

**The problem.** `VNFaceLandmarks2D.faceContour` runs cheek to cheek under the chin and the constellation holds **no crown point** (§6.1). The regulated measurement is chin to the **top of the skull**, and the sources are explicit that it stops at the crown, not the top of the hair (§6.1). A silhouette recovers the **outer envelope** — the top of the hair. For an updo, voluminous hair, a turban, a hijab or a wig, that envelope sits materially above the crown, so the validator **systematically over-reports head height**, failing compliant photos and passing non-compliant ones (§6.1). `VNFaceObservation.boundingBox` is landmark-derived with its top edge near the brow; the human-rectangle and body-pose requests return a box that is either clipped by the tight crop (head fills 50–69% of frame height) or pushed to the shoulders. Neither yields a crown (§6.1).

**The second estimator.** Crown position is **inferred from chin-to-eye-line proportions**, then **cross-checked against the silhouette envelope** (§6.2).

**The rule the app must implement.**

| Condition | Output |
|---|---|
| Envelope crown and inferred crown agree within tolerance | `pass` or `fail` on R1–R3, whichever the measurement gives |
| The two estimators **diverge** | **`cannot verify`** — never `pass`, never `fail` (§6.2) |

`cannot verify` is a first-class third state, not an error. It is the visible form of prohibition P6 and the mitigation for risk 1, "false pass" (§6.8). Capture enforcement buys the *background*, not the *skull*: a compliant updo still puts hair above the crown, so enforcement cannot remove the need for this state (§6.2). The divergence tolerance is **not specified — GAP G4.**

---

## 5. Print geometry (§6.3, §6.6)

### 5.1 Why 4×6 has zero remainder

2 across × 3 down of 2×2 in fills 4.0 × 6.0 in exactly, but **zero remainder is not itself the problem** (§6.3). The binding constraints are the printer's **non-printable margin, typically 3–6 mm**, and, borderless, **1–2 mm of overscan crop per edge**. A zero-remainder layout has no margin to absorb either, so the **outermost photos lose 3–6 mm** — and *a photo trimmed to 1.88 in is not a 2×2 in photo* (§6.3).

Because 4 and 6 are both exact multiples of 2, **no margined tiling of exactly-2-inch cells exists on 4×6 at all** (§6.3). Shrinking cells to ~1.9 in is **invalid** — US photos must be exactly 2×2 in — and cut marks need a gutter a zero-gutter layout does not have (§6.3). This result is listed in §10 as one of the report's sound findings.

### 5.2 The layouts

All cells are 2×2 in = **600×600 px at 300 DPI**. Margins marked *(stated)* are in the source; *(derived)* are arithmetic on the stated grid.

| Sheet | Grid | Cells | Content block | Margins | Gutter | Page px @300 | Note |
|---|---|---|---|---|---|---|---|
| **4×6 in** | 2×2 (**4-up**) | 4 | 4×4 in | 0 in L/R *(derived)*, 1 in T/B *(derived)* | 0 | **1200×1800** | Zero side margin → **borderless only**; this is why a calibration sheet ships (§6.3) |
| **5×7 in** | 2×3 (**6-up**) | 6 | 4×6 in | **0.5 in on all four edges** *(stated)* | 0 | 1500×2100 *(derived)* | The only fully-margined 2-in tiling that needs no gutter |
| **Letter 8.5×11** | 3×4 (**12-up**) | 12 | 6×8 in | **1.25 in sides** *(stated)*; 1.125 in T/B *(derived)* | **0.25 in** *(stated)* | **2550×3300** *(derived)* | The cut-mark-friendly variant (§6.3) |
| **A4 210×297 mm** | 3×4 (**12-up**) | 12 | 6×8 in | 28.8 mm L/R, 37.4 mm T/B *(derived)* | 6.35 mm *(derived)* | 2480×3508 *(derived)* | Same grid, different page box |
| **8.5×11** | 4×5 (**20-up**) | 20 | 8×10 in | **0.25 in sides** *(stated)*, 0.5 in T/B *(derived)* | 0 | **2550×3300** *(derived)* | Cheapest per photo, zero gutters (§6.3) |

**Two arithmetic defects in §6.3, flagged as GAP G5.**
1. §6.3's opening sentence describes the 4×6 case as *"2 across × 3 down"*, which is **six** cells, while the layout list calls the 4×6 sheet **4-up**. Six cells is also what the zero-remainder argument needs. The prototype ships 4-up (2×2) because the layout list and this spec's brief both name 4-up; the zero-remainder warning applies to the horizontal axis either way.
2. §6.3 states 12-up gives *"6 × 8 in with 1.25 in sides and 0.25 in gutters."* That does not close on Letter: `6 + 2(1.25) + 2(0.25) = 9.0 in > 8.5 in`. The only self-consistent reading is **1.25 in sides with zero column gutters and 0.25 in gutters between rows**, which leaves 1.125 in top and bottom. Derived values are used above.

### 5.3 Calibration and the 100% instruction (§6.6)

The print-fidelity risk is **unmeasured** and is the report's number-one unresolved risk (§6.6). A PDF carries a MediaBox; a driver applies its own default scaling; *"fit to page" is a common default*; the same file on three printers at three settings yields three physical sizes (§6.6). The $30, one-afternoon experiment — one calibration PDF, three printers (inkjet, laser, photo kiosk), three settings (100%/actual size, fit-to-page, borderless), measured with a ruler — **has not been run** (§6.6).

The prototype must ship every mitigation that does not wait on it (§6.6):

1. **Exact page size in the PDF** — the page box *is* the physical geometry (ref 16).
2. **Cut marks in a real gutter** — only where a gutter exists (12-up, not 4-up/6-up/20-up).
3. **A printed "print at 100% — do not scale" instruction** on the sheet itself.
4. **A calibration sheet offered before the paid export** — one page, printed and measured by the user before they spend the unlock.

---

## 6. Capture enforcement (§6.2)

Three mechanisms, described in §6.2 as *"build work rather than polish"*, costing **+2.0 person-weeks**, and *"the only reason a silhouette scan can be trusted at all."*

| # | Mechanism | What it gates |
|---|---|---|
| E1 | **Live framing overlay with a head-height band** | Composition, continuously, before capture. The band is drawn from the selected document's head-height clause (R1–R3). |
| E2 | **Background-uniformity and crown-contrast gate** | The **shutter itself**. Evaluated before release; the shutter does not fire while the gate fails. This is what makes the silhouette scan trustworthy — the product cannot assume a plain, evenly lit, high-contrast-at-crown background, so it must enforce one (§6.1, §6.2). |
| E3 | **Forced retake showing the failing region** | Progression past a failed check. The user is shown *where* it failed, not just that it did; export is blocked until the retake passes. |

Enforcement buys the background, not the skull — the `cannot verify` state (§4) remains necessary (§6.2). The crown-contrast gate has **no numeric threshold — GAP G6.**

---

## 7. The corpus (§6.5, §4.4, §4.5)

### 7.1 Why 12, not 220

| Quantity | Value | Source |
|---|---|---|
| Launch corpus | **12 documents** | §6.5, §4.5 |
| Full parity corpus | 220 documents | §6.5 |
| Corpus production rate | **2.5–4 documents per person-day** | §4.5, App. B #8 (derived) |
| 220 documents at that rate | 55–88 person-days = **11–17.6 person-weeks** | §4.5, §6.5 |
| Spec-engine budget for all 12 | 6.0 person-weeks | §6.4 |
| Parity programme | three to four months post-launch, 0.6–1.0 of one person | §6.5 |

**220 documents is unachievable inside the build window** — it exceeds the 13-week window on its own (§6.5). Twelve at launch is deliberate; the cost is that the app answers *"unsupported country"* for most of the world's demand, and the user's fallback is the counter (§6.5). Risk 7 requires the covered list and changelog to be published and coverage never implied (§6.8).

### 7.2 Countries in and out of scope

| Market | Status | Reason | Source |
|---|---|---|---|
| **United States** | **In**, launch order 1 | Only market where both the price anchor and the published cost of failure are quantified in the currency it charges in | v1.0 §2; v2.0 §3 |
| **United Kingdom** | **In** (v1.0 launch order 2) | HMPO publishes that booth/shop photos are more likely to be approved than self-capture — the strongest evidence for the product's relevance | v1.0 §2; v2.0 §3.4 |
| **Germany** | **Dropped** | From 1 May 2025 passport and ID photographs must be captured digitally and transmitted from an authorised on-site device or certified terminal; prints are no longer accepted. *"For a phone-capture product that is market closure."* | §4.4 |
| **Canada** | **B2B, not consumer** | Photo must be *"taken in person by a commercial photographer or photo studio"*, with the studio's name and address supplied at upload and the file saved directly from the camera. A **protected** market, not a closing one; the protected party is the photographer | §4.4 |
| **India** | **B2B, not consumer** | Capture at the Passport Seva Kendra | §4.4 |
| **Australia** | **B2B, not consumer** | Professional-provider capture required for citizenship photos | §4.4 |

**The structural finding:** the non-US market is not uniformly closing; it is **bifurcating** into markets where the applicant captures (and the arbitrage closes) and markets where a professional captures (and the arbitrage moves to the professional) (§4.4). The second is the B2B market.

**v1.0/v2.0 disagreement:** v1.0 §2 listed Canada and Australia at launch order 2/3 and India at 4. v2.0 §4.4 reclassifies all three as professional-capture markets. v2.0 governs: consumer scope is **US + UK**.

### 7.3 Documents actually named — **GAP G1**

The documents never enumerate the twelve. Only four are named anywhere:

| Document | Where named |
|---|---|
| US passport photo requirements | §4.3, §11 ref 23 |
| US visa photo requirements | §4.5, §11 ref 24 |
| DV-2025 instructions | §4.5, §11 ref 28 |
| DV-2026 instructions | §11 ref 27 |

Also named and then **excluded**: India's 35×45 mm specification, *"vendor-published, not issuer-published; dropped from the corpus"* (App. C).

**The remaining eight of the twelve are not specified.** A coder cannot build a 12-document library from these documents. The prototype must therefore either ship the four named documents and label the gap, or ship a 12-slot structure with eight placeholders — this is a product decision for the team lead, not an engineering one.

---

## 8. Pricing and paywall (§5, §6.4, §4.6)

| Item | Value | Source |
|---|---|---|
| Price | **$17.99** | §5, §5.2 |
| Instrument | **one-shot unlock — a non-consumable** | §2.6 (P3), §5.1 |
| Subscription | **none** — 3.1.2(a) is not triggered, *"a genuine structural advantage"* | §4.6 |
| IAP framework | **StoreKit 2**; Apple-signed JWS verified on-device via `appTransaction` | §6.4, §6.7, refs 17–18 |
| Entitlement infrastructure | **$0** for a one-shot unlock — with the stated cost that there is *"no revocation, no refund or chargeback handling, and no cross-device reconciliation beyond StoreKit's own sync"* | §6.7 |
| Trial | **Rejected on product logic** — the deliverable is a non-rival file, so a trial that permits export is a free unit and one that blocks export is not a trial | §5.4 |
| Credit packs | **Rejected on economics, not on 3.1.1** — a $3 credit makes the $17.99 unlock read as six credits and undercuts the product with its own price tag | §5.4 |
| Pre-registered price test | If **60-day conversion < 9%**, price drops to **$14.99** and the concept fails the hurdle honestly | §7.8 criterion 6; v1.0 §5.9 |

**The App Store rule that forces IAP:** **Guideline 3.1.1** — *"requires the unlock to be IAP"* (§4.6). A digital unlock cannot be sold outside Apple's IAP. Guideline 4.2 (minimum functionality) is the live review risk and is answered by demonstrable depth — *"a cropper is thin; a rule engine producing pass/fail findings per document, plus capture guidance and a print sheet, is not"* (§4.6). 4.2.6 is not engaged (§4.6).

**Paywall behaviour.** Single screen, single price, single button. Purchase restores via `appTransaction` on every launch with no network dependency beyond StoreKit. Because P5 forbids a server, entitlement is whatever StoreKit reports — the prototype must not invent a server-side receipt check.

---

## 9. Acceptance criteria

Each is checkable by looking at the app or running its tests.

| # | Criterion | Traces to |
|---|---|---|
| AC1 | Cold launch reaches Capture with zero taps, zero sign-in, zero permission wall other than camera | P2 |
| AC2 | After a full session and relaunch, the app container contains no image file | P1 |
| AC3 | StoreKit configuration contains exactly one product, of type non-consumable, priced $17.99; no auto-renewable product exists | P3, §5 |
| AC4 | Airplane mode: capture, diagnose, check, print-sheet and digital export all complete; only purchase is unavailable | P5 |
| AC5 | No string in the app bundle or metadata matches `approved`, `guaranteed`, `official`, `accepted`, `government-approved` | P6 |
| AC6 | No code path writes pixels behind the subject; segmentation output is consumed for measurement only | P4, 8 FAM 402.1-3(g) |
| AC7 | The Library lists exactly the covered documents and shows an explicit "unsupported country" state for anything else; each document shows a dated clause and a changelog entry | F6, §6.5, §6.8 |
| AC8 | Head height is evaluated in millimetres against **25.4–34.9**, and the value 22 never appears in the rule table or the code | §4.5, R1–R2 |
| AC9 | Every one of the six named checks returns `pass` / `fail` / `cannot verify`, and `cannot verify` is reachable when the envelope and the chin-to-eye-line estimators diverge | §6.2, §4 |
| AC10 | The shutter does not fire while the background-uniformity and crown-contrast gate is failing | E2 |
| AC11 | A failed check produces a retake screen that names and highlights the failing region, and blocks export until it passes | E3 |
| AC12 | The 4×6 PDF has a 1200×1800 px page box containing four 600×600 px cells; 5×7 is 1500×2100 with 0.5 in margins; Letter 12-up is 2550×3300 with 0.25 in row gutters | §6.3, §5.2 |
| AC13 | Every print sheet carries the rendered instruction "print at 100% — do not scale" | §6.6 |
| AC14 | A calibration sheet is offered before the paid export, and printing it does not consume the unlock | §6.6 |
| AC15 | The digital export writes DPI as metadata and matches the selected document's portal geometry | F5, ref 15 |

---

## 10. Gaps — what the documents do not specify

A coder cannot implement these from the sources. Each needs a decision before the corresponding screen is built.

| # | Gap | Consequence | Suggested owner |
|---|---|---|---|
| **G1** | The twelve launch documents are never listed; only four are named (§7.3) | F6 cannot be built to spec; AC7 cannot be satisfied as written | team-lead |
| **G2** | Eye line, centring, shadow, expression and glasses are named as checks (§2.6) with **no tolerance, band or classifier** | F3 ships five checks with invented thresholds, or ships them as `cannot verify` only | team-lead |
| **G3** | **Headroom is absent from all three documents** | No headroom rule can be implemented; only the 50–69% band constrains it indirectly | team-lead |
| **G4** | The divergence tolerance between the envelope crown and the chin-to-eye-line crown is not stated (§6.2) | `cannot verify` has no trigger condition; AC9 is unfalsifiable without a number | team-lead |
| **G5** | §6.3's 4×6 layout is described as both 4-up and 2×3 (six cells), and its 12-up margins do not close on Letter (§5.2) | Print layout cannot be coded exactly as written | team-lead |
| **G6** | The crown-contrast gate has no numeric threshold (§6.2) | E2 cannot be tuned; the shutter may never release or always release | team-lead |
| **G7** | Whether a third-party app may auto-crop is inferred, not stated: 8 FAM 402.1-2(4)(a)/(5)(a) are Department powers (§4.3) | F1 rests on an interpretation | team-lead |
| **G8** | The digital export's pixel dimensions, colour space and file format are never specified (F5) | AC15 can only test DPI metadata and aspect | team-lead |
| **G9** | No input-resolution minimum for a captured image is stated; 300 DPI is an output target only (ref 15: DPI is metadata, not a pixel property) | No rejection rule for a low-resolution source | team-lead |
| **G10** | No design system, type scale, colour or layout guidance exists in any of the three documents | Visual design is unconstrained by research | design owner |

---

## 11. Provenance notes

- **Labels preserved.** Figures quoted above carry their source label where the report gives one. The 2.5–4 documents/person-day corpus rate is labelled *derived* (App. B #8). The 300–412 px head height is *derived* from the 300 DPI cell and the 1–1⅜ in rule. The 4-up, 6-up, 12-up and 20-up pixel dimensions other than 1200×1800 are *derived*, not stated.
- **Withdrawn figures that must not reappear in the app.** The "roughly 1,000 px head" figure was withdrawn as a factual error by a factor of 2.5–3 (App. C #5). The 39.7% crop-rejection figure and the 0.4% background figure are **directional only** and must not be used in marketing copy (§3.2, App. C). India's 35×45 mm spec is dropped (§7.3).
- **The business conclusion is out of scope.** §10 and §8 conclude the consumer business should not be built. That does not change any requirement above; the §6 thesis states the build chapter *"survives review essentially intact, and is the strongest engineering work in the report,"* and §10 lists the print geometry, the 22 mm finding, the 8 FAM reading and the 128-day estimate as findings that survive.
