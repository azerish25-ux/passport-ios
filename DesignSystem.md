# PassportProof design system

PassportProof is a quiet, private photo studio. Its interface combines a warm
canvas, green-black ink, original portrait artwork, generous spacing and precise
file specifications. Every screen should make the next action easy to find and
explain what the app can actually establish about a photograph.

## Palette

`Theme.swift` resolves these colours through dynamic UIColor providers.

| Role | Light | Dark | Purpose |
|---|---|---|---|
| `paper` | `#F5F4EF` | `#121B19` | Main canvas |
| `paperRaised` | `#FFFEFA` | `#1C2824` | Content cards and action bars |
| `paperSunk` | `#EAEDE5` | `#0D1513` | Recessed details |
| `ink` | `#19312B` | `#EFF3EA` | Primary copy and main button fill |
| `inkSecondary` | `#52625A` | `#B4C5B9` | Supporting instructions |
| `inkTertiary` | `#66756C` | `#9CAF9E` | Dates and secondary metadata |
| `accent` | `#186B54` | `#8BDBB9` | Interactive actions and emphasis |
| `sageWash` | `#E3ECE3` | `#243B31` | Quiet callouts and illustration ground |
| `sageStrong` | `#BBCDBB` | `#42634F` | Decorative artwork and separators |
| `rule` | `#D9DFD4` | `#35453B` | Thin card borders and dividers |

Pass, fail and review retain separate semantic colours. A sage illustration or
accent-coloured button is not a passing result. Every finding pairs colour with
a status word and an icon.

## Typography

- Editorial titles use the system **serif Large Title** at regular weight.
- Interface labels and instructions use SF Pro semantic text styles.
- Dimensions, measured values and file sizes use SF Mono where alignment helps.
- Eyebrows use a restrained caption style with 1.4 pt tracking.
- Buttons use sentence case and semibold body text.
- Essential text grows with Dynamic Type. Artwork can disappear at accessibility
  sizes to give the content room; instructions and actions must not be scaled down.
- Decorative logo subtitles and artwork labels are not essential content.

## Space and shape

Spacing follows the 4 pt rhythm: 4, 8, 12, 16, 20, 24, 32 and 48.
Screen margins are 20 pt. Standard card radius is 22 pt, compact document cards
18 pt, primary buttons 16 pt, and large illustration containers 28 pt. Thin
borders and tonal changes provide hierarchy without heavy shadows.

Touch targets are at least 44 pt. Primary actions have a minimum 52 pt height,
horizontal padding and wrapping labels. Text-bearing cards have no fixed height.

## Shared components

| Component | API and behaviour |
|---|---|
| `StudioCard` | `StudioCard(padding: CGFloat = 20) { content }`; raised content-sized surface with a thin border |
| `StudioEyebrow` | `StudioEyebrow(title: String)`; short accent-coloured section heading |
| `StudioMark` | Original layered photo-card mark, 42 × 42 pt; decorative |
| `StudioPortraitArt` | `style: .portrait / .printSheet / .digital`, `compact: Bool = false`; caller supplies a frame |
| `StudioStepProgress` | **One-based** `current: 1 / 2 / 3` for Capture / Check / Export; stacks at accessibility text sizes |
| `PrimaryButtonStyle` | Full-width ink button; respects both explicit and environment disabled state |
| `AccentButtonStyle` | Full-width accent button with the same wrapping and motion rules |
| `SecondaryAction` | Text action with a minimum 44 pt target |

All existing Theme, Typography, ScreenTitle, StatusInk and ReadoutStrip APIs remain
available to the feature screens.

## Original artwork

The shared artwork is constructed from SwiftUI Canvas paths: framed paper,
portrait silhouettes, a measured edge, printable sheets and a small JPEG label.
It scales without a downloaded image or generated photographic asset. These are
decorative illustrations, not example photographs or proof of document acceptance.
The artwork is hidden from accessibility; adjacent text supplies the file format.

## Screen compositions

### Document library

A compact persistent wordmark and privacy action sit above a warm editorial
introduction. The main action explicitly starts a US passport photo. Three compact
workflow cards make the distinction between printed passport photos and digital
US visa/DV photos visible. Free checks and paid export are disclosed before the
user enters the flow. Export details sit in the process card rather than being
buried below a long product footer.

### Document brief

Show the final format first, then practical capture guidance and the essential
rules. Additional encoded requirements and update history remain in accessible
disclosures. The source link identifies the official issuer. A persistent action
bar provides the next step and repeats that checks are free.

### Export unlock

The page shows original output artwork, the price supplied by StoreKit when a
product is available, purchase/restore/recovery states, and a plain-language
free-versus-paid distinction. Do not substitute invented store availability,
ratings, customer counts, discounts or acceptance guarantees. A purchase changes
export access, not the photo diagnosis.

### Privacy

Lead with a concise promise, then explain photos, permissions, data collection,
purchases and external links. Be explicit that copies a user saves or shares are
managed by the user, even after temporary app staging is removed.

## Accessibility and motion

- Light and dark appearances use role-based dynamic colours.
- Accessibility text sizes stack step progress and measurement rows; decorative
  imagery is removed where it would compete with readable content.
- Interactive text has a visible target and supports VoiceOver.
- Navigation and action accessibility identifiers are preserved across redesigns.
- Press feedback is a brief opacity change. Reduce Motion removes its animation.
- Do not add looping decoration, spring overshoot or motion required to understand
  a result.

## Product language

Use “photo checks,” “review,” “print sheet” and “digital file.” State dimensions
when they are useful. Explain unresolved visual checks in normal language.
Avoid “approved,” “guaranteed compliant,” fake review quotes or any design that
makes a heuristic measurement look like a government decision.
