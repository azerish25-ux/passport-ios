# PassportProof — Design System

**Precision instrument / technical document.** The app is a measuring instrument, not a photo
editor. Every screen is a calibration sheet: a ruled surface, a stated range, a measured value,
a source, a date. Nothing is decorative. Nothing is promised.

Three rules: **separation by rule, never by shadow** (hairlines and tone shifts only); **numbers
outrank prose** (a measurement is larger, monospaced, and adjacent to its range); **colour marks
truth, never taste** (signals on findings only; the accent marks *where you are*, never *what is
true*).

## 1. Palette

Warm paper, warm ink. Dark mode is a warm near-black, never `#000`.

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#F4F1EA` | `#17140E` | Screen background, sheet ground |
| `paperSunk` | `#EAE5D8` | `#100E09` | Recessed wells, inactive tab strip, expanded row body |
| `paperRaised` | `#FBF9F4` | `#201C14` | Top bar, readout strip on non-camera screens |
| `ink` | `#14120F` | `#EDE8DC` | Primary text, primary button fill, measured marker |
| `inkSecondary` | `#4C463A` | `#A9A292` | Labels, section headers, range text |
| `inkTertiary` | `#7B7364` | `#7C7565` | Sources, dates, units, disabled text |
| `rule` | `#D8D2C4` | `#332F26` | Hairline separators (0.5pt) |
| `ruleStrong` | `#B4AC99` | `#4C4638` | Section rules, measurement axis (1pt) |
| `accent` | `#10565C` | `#4FA3A8` | Selected tab underline, focus ring, caret. Nothing else |
| `signalFail` | `#B23A1E` | `#E0704F` | FAIL only |
| `signalPass` | `#2F6B4F` | `#6FAE8C` | PASS only |
| `signalVerify` | `#82631B` | `#C9A44E` | CANNOT VERIFY only |
| `failWash` | `#F3E3DC` | `#2A1712` | FAIL row ground |
| `verifyWash` | `#EFE8D3` | `#241E0E` | CANNOT VERIFY row ground |
| `bandFill` | `#DCD5C4` | `#2E2A21` | Allowed-range band on the measurement bar |
| `inkPressed` | `#2B2721` | `#D6D0C2` | Pressed primary button |
| `onInk` | `#F4F1EA` | `#16140F` | Text on ink fill |
| `onInkMuted` | `#C6BFAE` | `#4C4638` | Secondary text and rules on ink fill |
| `scrim` | `#0B0A08` @ 62% | same | Flat camera scrim. Opaque edges, no blur |

**Contrast.** `ink` on `paper` 16.8:1 · `inkSecondary` 8.4:1 · `signalFail` 5.3:1 ·
`signalPass` 5.6:1 · `signalVerify` 5.0:1 · `accent` 7.4:1. The brief's ochre `#8A6A1F` measured
4.47:1 on paper, so it is darkened to `#82631B`. **Never** gradient-fill, tint, or shadow any of
these. `signalPass` is not a success flourish; it is the statement "this dimension is inside
tolerance."

## 2. Typography

SF Pro for language. SF Mono for anything measured, coded, or cited. Mono is not styling — it is
the mark of a value you could check with a ruler.

| Style | Face | Size / Line | Weight | Tracking | Case |
|---|---|---|---|---|---|
| `display` | SF Pro | 34 / 40 | Regular | −0.6 | Sentence |
| `title` | SF Pro | 24 / 28 | Medium | −0.3 | Sentence |
| `body` | SF Pro | 16 / 24 | Regular | 0 | Sentence |
| `bodySmall` | SF Pro | 14 / 20 | Regular | 0 | Sentence |
| `meta` | SF Pro | 12 / 16 | Regular | +0.1 | Sentence |
| `sectionLabel` | SF Pro | 11 / 14 | Semibold | +1.6 | UPPER |
| `findingLabel` | SF Mono | 10 / 12 | Semibold | +1.4 | UPPER |
| `measurement` | SF Mono | 30 / 32 | Medium | −0.6 | Figures |
| `measurementInline` | SF Mono | 17 / 20 | Medium | −0.2 | Figures |
| `unit` | SF Mono | 11 / 13 | Regular | +0.8 | UPPER |
| `tabular` | SF Mono | 12 / 16 | Regular | +0.2 | As written |
| `mrz` | SF Mono | 13 / 18 | Medium | +2.2 | UPPER |
| `button` | SF Pro | 14 / 18 | Semibold | +1.1 | UPPER |

Rules:

- **Tabular figures everywhere.** Never proportional digits in a table, readout, or list.
- `measurement` is used once per screen where possible — the primary value. Inline values drop to
  `measurementInline`. A measurement is never smaller than the body text beside it.
- `mrz` is for document codes and reference IDs only (`USA`, `PP-2026-0417`, `ICAO 9303`).
- Uppercase only on `sectionLabel`, `findingLabel`, `unit`, `button`, `mrz`.
- Maximum measure 64 characters. Numbers never use thousands separators. Ranges use an en dash:
  `32.0–36.0 mm`. Never bold a value to make it important — enlarge it.

## 3. Space, radius, stroke

**Space** (4pt base): `2 · 4 · 8 · 12 · 16 · 24 · 32 · 48`. Screen margin **20pt**; row padding
**20 / 12**; value-to-unit gap **3pt**; gap between a section rule and its first row **0** — the
rule is the boundary, not a decoration.

**Radius**: containers **2pt**; controls, rules, buttons, and the camera guide **0pt**. There is no
other radius in the app. A 16pt card does not exist here.

**Stroke**: hairline **0.5pt**, rule **1pt**, emphasis **2pt**, status rail **3pt**. Hairlines are
always 0.5 — never 0.33, never "1px". At @3x they render 1.5px, which reads as a ruled line rather
than a border.

## 4. Components

### 4.1 Finding row

Full-bleed. No card. Separated by a 0.5pt `rule` bottom hairline that runs edge to edge.

```
┌─┬──────────────────────────────────────────────────────────────┐
│▌│ FAIL     Head height                              31.4 mm    │  ← 3pt rail
│ │          Required 32.0–36.0 mm · measured 31.4 mm            │
│ │          ICAO 9303 Pt 3 §3.2 · verified 2026-03-14           │
└─┴──────────────────────────────────────────────────────────────┘
```

| Element | Spec |
|---|---|
| Rail | 3pt wide, full row height, flush left, `signalFail` / `signalPass` / `signalVerify` |
| Status label | `findingLabel`, fixed column **100pt**, vertically centred on line 1 |
| Rule name | `body`, `ink`, baseline-aligned with status label |
| Measured value | `measurementInline`, right-aligned, `ink` normally; `signalFail` when FAIL |
| Required range | `meta`, `inkTertiary`, second line, 2pt below |
| Source + date | `tabular`, `inkTertiary`, third line, 2pt below, `·` separator |
| Padding | 20 leading (after rail) / 20 trailing / 12 vertical |
| Min height | 64pt collapsed, auto when expanded |

States:

- **PASS** — rail `signalPass`, label `signalPass`, value `ink`, ground `paper`.
- **FAIL** — rail `signalFail`, label `signalFail`, value `signalFail`, ground `failWash`.
- **CANNOT VERIFY** — rail `signalVerify` drawn **dashed** (2pt on / 2pt off) to say "unresolved",
  label `signalVerify`, value `—` in `inkTertiary`, ground `verifyWash`. The reason replaces the
  range line: "Crown edge indistinguishable from background."
- **Expanded** — ground `paperSunk`; the measurement bar (§4.2) sits 16pt below the source line,
  inset 20pt both sides. A 0.5pt `rule` closes the row.

A row is tappable across its full width. No chevron: expansion is shown by the bar appearing.

### 4.2 Measurement bar

The core gauge. Geometry is fixed; only the data varies. Given `required = [lower, upper]`,
`span = upper − lower`, `W = content width`:

```
domainLo = max(0, lower − 0.6 × span)
domainHi = upper + 0.6 × span
x(v)     = W × (v − domainLo) / (domainHi − domainLo)
```

Vertical layout, total height **34pt**:

| Element | y (pt) | Spec |
|---|---|---|
| Range band | 7 → 13 | x(lower) → x(upper), fill `bandFill`, 1pt `rule` on top and bottom edges |
| Axis | 10 | 1pt `ruleStrong`, full width, 0 → W |
| Ticks | 10 → 14 | 0.5pt `rule`, at 5 evenly spaced domain positions including both ends |
| Tick labels | baseline 22 | `unit`, `inkTertiary`; only `domainLo`, `lower`, `upper`, `domainHi` are labelled |
| Marker | 2 → 18 | 2pt wide vertical bar at x(measured), 16pt tall |
| Connector | 10 | when out of range: 1pt `signalFail` from the nearest band edge to the marker |

Marker colour: `ink` when `lower ≤ measured ≤ upper`, `signalFail` otherwise. The band never
changes colour — the band is the rule, the marker is the fact.

`CANNOT VERIFY`: band drawn normally, no marker, no connector. A 1pt dashed `signalVerify`
horizontal line spans the band at y=10 and `unit` text "NO MEASUREMENT" sits at the band's
left edge, 4pt above it.

Below the bar, 8pt gap, one line — `MEASURED 31.4 mm        RANGE 32.0–36.0 mm`. Words in
`tabular` / `inkTertiary`, figures in `measurementInline` / `ink` (or `signalFail`). Two columns,
left-aligned, 24pt apart. No box, no background.

### 4.3 Document row

Height **72pt**, full-bleed, 0.5pt `rule` between rows.

| Element | Spec |
|---|---|
| Country code | `mrz`, `inkSecondary`, fixed width **56pt**, left-aligned at margin |
| Document name | `body`, `ink` — "Passport", "Visa — B1/B2" |
| Spec summary | `meta`, `inkTertiary`, second line: "2 × 2 in · 51 × 51 mm · 300 dpi" |
| Chevron | `chevron.right`, 11pt, `inkTertiary`, 20pt from trailing edge |
| Selected | 2pt `accent` rail flush left; ground `paperSunk`; name becomes `ink` at full weight |
| Verified chip | none. Recency is text, not a badge: "verified 2026-03-14" in `tabular` |

The code column never wraps or truncates; codes longer than four characters drop to `tabular` at
11pt.

### 4.4 Section header

Height **28pt**. Label `sectionLabel` in `inkSecondary`, 20pt from margin, 12pt clear above.
Optional trailing count or date in `tabular` / `inkTertiary`, right-aligned at margin. Rule: 1pt
`ruleStrong`, 8pt below the label baseline, full-bleed. Zero space below the rule — the first row
starts immediately. Headers are never inside containers and never carry backgrounds.

### 4.5 Primary button

- Width screen − 40pt, height **52pt**, radius **0**. Fill `ink`; label `button` / `onInk`.
- Pressed: fill `inkPressed`, 80ms opacity-only transition. Disabled: fill `rule`, label
  `inkTertiary`, no opacity change.
- One per screen, pinned 16pt above the safe-area bottom, on `paper`.
- Secondary action: `button` style, `ink`, no fill, no border, 44pt tap target, 1pt `ruleStrong`
  underline offset 6pt below baseline.
- Destructive uses `signalFail` as the *label* colour only; the fill stays `ink`. Never a red
  filled button — red belongs to findings.

### 4.6 Capture overlay

Camera feed, full-bleed, no blur anywhere.

| Element | Spec |
|---|---|
| Scrim | `scrim` (`#0B0A08` @ 62%), flat, hard-edged at the guide rect. No feathering |
| Guide | Inset 24pt horizontally, 96pt from top, aspect locked to the document (e.g. 35:45) |
| Corner ticks | 4 corners, 14pt long, 1.5pt wide, `onInk`, drawn as an L — no full border |
| Head band | Between crown and chin lines, fill `captureBand` (`onInk` @ 10%), 1pt dashed edges (3 on / 2 off) |
| Crown line | 1pt solid `onInk`, full guide width, label "CROWN" in `unit` 6pt above, left-aligned |
| Chin line | 1pt dashed `onInk` (3 on / 2 off), label "CHIN" 6pt below, left-aligned |
| Eye line | 1pt dashed `onInk` (4 on / 3 off), label "EYE" right-aligned, 6pt above |
| Centre line | 1pt dashed `onInk` @ 45%, vertical, full guide height, no label |
| Readout strip | Height **56pt**, fill `ink`, pinned above the shutter. Three columns split by 1pt `onInkMuted` vertical rules at 1/3 and 2/3 |

Readout column: value in `measurementInline` (`onInk`), caption in `unit` (`onInkMuted`) 2pt below:
`31.4 mm` / HEAD · `+1.2 mm` / EYE OFFSET · `0.4°` / TILT. Values update at 4 Hz and never animate.
Band edges come from the live document spec, so they move when the document changes and never
otherwise. Nothing in the overlay pulses.

## 5. Motion

**One animation exists.** Finding rows settling in, after a measurement completes.

| Property | Value |
|---|---|
| Curve | `timingCurve(0.2, 0, 0, 1)` — no overshoot, no spring |
| Duration | 220ms |
| Stagger | 40ms per row, top to bottom, max 6 rows (rows 7+ share the last offset) |
| Transform | `offset(y: +6 → 0)`, `opacity 0 → 1`. No scale, rotation, or blur |
| Reduce Motion | stagger removed, duration 120ms, opacity only |

Everything else is instant: state changes, marker movement, tab switches. Standard UIKit sheet
timing is acceptable because it is the system's, not ours. No bounce, spring, parallax, shimmer,
or skeleton loading. Haptics confirm rather than celebrate: `.rigid` on measurement completion,
`.light` on selection. Never on scroll, never repeated.

## 6. Implementation

`PassportProof/Design/Theme.swift` is the only source of these values. It exposes:

- `Theme.paper / paperSunk / paperRaised / ink / inkSecondary / inkTertiary / rule / ruleStrong`
- `Theme.accent`, `Theme.signalFail / signalPass / signalVerify`, `Theme.failWash / verifyWash`
- `Theme.bandFill / inkPressed / onInk / onInkMuted / scrim / captureBand`
- `Theme.Spacing`, `Theme.Radius`, `Theme.Stroke`, `Theme.Metrics`, `Theme.Motion`
- `Typography.<style>.text(_:)`, `Typography.value(_:unit:)`, `.typeStyle(_:)` for multi-line blocks
- `Theme.Rule` (horizontal/vertical hairline), `Theme.SectionHeader`

All colours resolve through `UIColor { traits in … }`; no call site branches on `colorScheme`.
**Do not** add a colour, size, or radius outside this file. If a screen needs one, the system is
wrong — argue it here first.
