# PassportProof — Design System

**Calm precision, not technical intimidation.** PassportProof should feel like a
well-made private photo studio: warm paper, deep green ink, exact measurements
and plain language. It is not a photo editor and never looks like a generic
document utility.

Three principles govern the product:

1. **One decision per screen.** Capture, check and export are distinct steps.
2. **Truth before reassurance.** Status always combines icon, text and colour.
   “Review” is a legitimate result, not an error to hide.
3. **The photo leads.** Guidance supports the image rather than covering it in
   instrumentation.

## 1. Palette

All interface colours resolve through dynamic `UIColor` providers in
`Theme.swift`. Hero/camera foregrounds are fixed because their grounds stay dark
in both appearances.

| Token | Light | Dark | Use |
|---|---|---|---|
| `paper` | `#F4F1EA` | `#17140E` | Screen ground |
| `paperSunk` | `#EAE5D8` | `#100E09` | Recessed wells, code tiles |
| `paperRaised` | `#FBF9F4` | `#201C14` | Cards, bottom bars |
| `ink` | `#14120F` | `#EDE8DC` | Primary text, primary fill |
| `inkSecondary` | `#4C463A` | `#A9A292` | Supporting copy |
| `inkTertiary` | `#6F6758` | `#9C9483` | Non-essential metadata; ≥4.5:1 |
| `rule` | `#D8D2C4` | `#332F26` | Hairlines and card borders |
| `accent` | `#0D6B60` | `#63D3BD` | Interactive actions and focus |
| `onAccent` | `#FFFFFF` | `#092821` | Text on accent |
| `signalPass` | `#2F6B4F` | `#6FAE8C` | Passing state only |
| `signalFail` | `#B23A1E` | `#E0704F` | Failed/blocking state only |
| `signalVerify` | `#82631B` | `#C9A44E` | Unresolved/review state only |
| `heroTop` | `#183E3B` | `#102C2A` | Hero gradient start |
| `heroBottom` | `#0C2529` | `#081C1E` | Hero gradient end |
| `heroInk` | fixed `#F7F4EC` | fixed | Text on hero |
| `heroMuted` | fixed `#C4D1C9` | fixed | Secondary text on hero |

Rules:

- Red is never a decorative brand colour. It means a failed or blocking state.
- Accent is for actions and focus. It does not imply success.
- Never use colour alone: pair it with an icon and a text label.
- Tertiary text is reserved for dates, source hosts and non-essential metadata;
  essential instructions use `inkSecondary` or stronger.

## 2. Typography

SF Pro for language. SF Mono for measurements, document codes and exact values.
All numeric design tokens map to semantic text styles so Dynamic Type scales the
whole interface.

| Style | Relative text style | Weight | Tracking | Case |
|---|---|---|---|---|
| `display` | Large Title | Regular | −0.6 | Sentence |
| `title` | Title 2 | Medium | −0.3 | Sentence |
| `body` | Body | Regular | 0 | Sentence |
| `bodySmall` | Subheadline | Regular | 0 | Sentence |
| `meta` | Caption | Regular | +0.1 | Sentence |
| `sectionLabel` | Caption 2 | Semibold | +1.6 | UPPER |
| `findingLabel` | Caption 2 Mono | Semibold | +1.4 | UPPER |
| `measurement` | Title Mono | Medium | −0.6 | Figures |
| `measurementInline` | Headline Mono | Medium | −0.2 | Figures |
| `unit` | Caption 2 Mono | Regular | +0.8 | UPPER |
| `tabular` | Caption Mono | Regular | +0.2 | As written |
| `mrz` | Footnote Mono | Medium | +2.2 | UPPER |

Rules:

- Use tabular/monospaced digits for measurements and ranges.
- Never shrink essential text below its Dynamic Type size. Values may use a
  minimum scale factor only inside a fixed preview card, never for instructions
  or actions.
- Use an en dash for ranges: `25.4–34.9 mm`.
- Maximum prose measure is roughly 64 characters; cards use generous vertical
  rhythm instead of dense columns.

## 3. Space, shape and elevation

- Spacing scale: `2 · 4 · 8 · 12 · 16 · 24 · 32 · 48`.
- Screen margin: **20 pt**.
- Card radius: **16–20 pt**; hero radius **28 pt**; icon tile **12–18 pt**.
- Tap target: minimum **44 × 44 pt**.
- Primary button height: minimum **52 pt**.
- Cards use a 0.5–1 pt border plus tonal fill. Avoid heavy drop shadows; hierarchy
  comes from surface tone, spacing and type.
- On iPad the root navigation content is capped at **820 pt** and centred.

## 4. Components

### Primary action

- Full-width, 16 pt radius, `ink` fill, `onInk` label, 52 pt minimum height.
- Disabled: `rule` fill, tertiary label, no unexplained dead end.
- Pressed: subtle opacity change, 80 ms.

### Accent action

Used on dark hero surfaces only. `accent` fill, `onAccent` label, same geometry
as the primary button.

### Secondary action

Text-only accent label with a 44 pt minimum tap target. No persistent underline.
The label must describe the action (“Retry”, “Restore purchase”), not “Click
here”.

### Cards

- `paperRaised` fill, 16–20 pt radius, subtle `rule` border.
- Status cards add a 4 pt leading rail and a status-tinted wash.
- Cards grow vertically with text; no fixed heights on text-bearing surfaces.

### Finding row

Collapsed row shows icon, status word, title, measured value and required range.
Expanding reveals the plain-language explanation, measurement bar and source.
The whole row is a Button with an accessibility hint and expanded/collapsed
state. The measurement bar is visual; its essential values are already in the
accessible row label.

### Camera

- Full-bleed preview with a top and bottom scrim.
- Head-height guide drawn from the selected document.
- Live status card states what is missing, not a generic “hold still”.
- Custom shutter is disabled until the gate passes; it is a white ring with a
  filled centre and a visible progress state.
- Close and privacy controls remain reachable at large text sizes.

## 5. Motion

- Finding rows settle with a 220 ms timing curve and a maximum 6-row stagger.
- Reduce Motion disables offset/stagger; opacity may change instantly.
- Press feedback is 80 ms and never bouncy.
- Loading uses native `ProgressView`; no looping decorative animation.

## 6. Accessibility

- Every flow has a non-gesture alternative: crop zoom slider and custom move
  actions, visible buttons, and descriptive labels.
- VoiceOver reads status as text, not colour. Technical overlays are hidden from
  assistive technology; findings carry the essential values.
- Decorative camera guides and branding symbols are hidden.
- Test at AX5 with no clipped actions. Test light/dark contrast, Reduce Motion,
  VoiceOver and 320 pt-class width.
- Never communicate an error only through haptics or colour.

## 7. Brand assets

- **App icon:** deep-teal capture field, ivory photo card, crown/chin measurement
  lines, head silhouette and validation seal. Opaque 1024 × 1024 RGB.
- **Launch symbol:** simplified seal/check mark in the same deep teal, on the
  paper launch background, with light/dark-compatible colour set.
- Both are generated from original geometry by `Tools/generate_icon.py`; no
  third-party artwork or generated photographic content is shipped.
