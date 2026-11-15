# AnKi identity — « Lotus au clair de lune »

The source of truth for what makes a screen *look and feel like AnKi*. The palette is option A
« Lotus & nuage », chosen by the maintainer on 2026-11-15 among three directions prototyped on the
real screens. Every value below comes from the palette audit (`scripts/palette_audit_test.dart`)
run on that prototype with Flutter 3.47.9; if a seed or an override changes, re-run the audit and
update the tables.

## Contents
1. Concept · 2. Signature elements · 3. Color · 4. Typography · 5. Shape · 6. Spacing & layout ·
7. Depth & glass · 8. Motion · 9. Haptics · 10. Icons & illustration · 11. Voice & microcopy

---

## 1. Concept

**AnKi** (暗記, *learn by heart*) + **Kairos** (the right moment): never miss the moment that
matters to someone you love. The brand already lives in the assets: a lotus in bloom before a
soft blue cloud, with plum blossoms (`icon.png`); a smiling lavender moon above lotus buds and
mint leaves (`lune.png`).

The identity is **« Lotus au clair de lune »**: every birthday is a lotus opening. By day, a dawn
on the pond — blush canvas, lotus pink, cloud blue. On the day itself the flower turns vivid,
raspberry to plum red. By night, the pond under the moon — plum night and night blue, the
lavender moon watching. Three adjectives to test every screen against:
**warm · blooming · precise** (« chaleureux · épanoui · précis »).
- *Warm*: lotus-tinted surfaces, human copy, the person's name and face first.
- *Blooming*: color and life on every screen — the brand is in the canvas, the containers and
  the moments, not only on the hero.
- *Precise*: dates, ages and countdowns exact and legible at a glance; one clear action per
  screen.

A grey, cold or vague screen is off-brand — that was the « terne » UI this identity replaced. A
loud screen is off-brand too: vivid color everywhere, accents competing with the one action.
**Logo test**: hide the name and the icon; the screen must still read as AnKi.

Benchmarks for the *feel*: Airbnb (one warm brand color carried through every surface),
Headspace (soft and reassuring), Spotify (an accent that means *act here*), Google Calendar
(clarity of time), Things 3 (crafted calm).

## 2. Signature elements

Originality lives in color, surfaces and these signatures; controls stay conventional. Use each
signature where listed, nowhere else: a signature seen everywhere stops being one.

| # | Element | Where | Rules |
|---|---------|-------|-------|
| S1 | **Lotus hero gradient** | Next-birthday hero, celebration (J-0), onboarding hero, the person page header (P10) | Max one per screen. Before the day: light = dawn on the pond (lotus → cloud, dark text), dark = the pond at night (berry → night blue). On J-0: raspberry → plum red, the day the flower turns vivid. Values in §3.4. |
| S2 | **Moon mascot** (`AppAssets.moon`) | Empty states, onboarding, success/zero-inbox moments | Never in dense screens or lists. Max one per screen. Shines on the plum night — no white plate behind it. |
| S3 | **Orbit countdown** *(`lib/core/common/orbit_countdown.dart`)* | Around the number of the hero before the day and of the person page header (the coming age, else the days), and of every agenda row (the days left) | A small lavender moon travels a thin orbit: the arc covers the last 29 days and closes on the day in blossom (mint once wished), around the age on the person header, else around a cake (a check once wished). The drawing is mute: the number and its row text carry the meaning, TalkBack reads « Dans 12 jours » / « Aura 34 ans ». On gradients pass `trackColor: onHero` at 25 % and `arcColor: onHero`. Not on the J-0 hero (big age instead). The text next to it never repeats the orbit's number (no « Dans 12 jours » under « 12 jours »). The only S3 form in the app. |
| S4 | **Petal rain** *(`features/birthday/widgets/blossom_rain.dart`)* | Hero on the birthday itself (J-0) | Soft falling lotus petals and plum blossoms ≤ 2.5 s (2.4 s), once per person per day, `mediumImpact`. Skipped when reduce-motion is on. Never generic confetti. Tones `AnKiColors.petals`: lotus pinks and the gold of the stamens. |
| S5 | **Floating glass pill navigation** | Main tabs (`core/common/bottom_bar.dart`) | Blurred translucent pill, radius 32, content scrolls beneath; the glass takes the canvas tint (blush, plum night). Labels must stay available to TalkBack. |
| S6 | **Big tabular numerals** | Countdown, age, counts, a series' last volume | Outfit w800, `FontFeature.tabularFigures()`, letter-spacing −1. One per card: the orbit's number, the J-0 hero's age (`displaySmall`), or the last owned volume of a shelf row (`headlineMedium`) and of the series page header (`displaySmall`), `LastVolumeNumber` in `features/books/widgets/series_tile.dart`. |

## 3. Color

### 3.1 Base scheme — seed « Lotus » `#FFB6BF`, `DynamicSchemeVariant.vibrant`

`AppTheme` builds `ColorScheme.fromSeed(seedColor: #FFB6BF, dynamicSchemeVariant: vibrant)`
(the light petal of `icon.png`), then overrides two role families with `copyWith`:
- `secondary*` ← the `primary*` roles of the same seed in **tonalSpot**. Vibrant's own secondary
  is a terracotta (`#82524A`, container `#673B34` in dark) that turned tonal buttons and the nav
  indicator brown;
- `tertiary*` ← the `primary*` roles of the cloud `#C5DEFF` in tonalSpot: the icon's sky blue,
  the calm counterpoint to the pink.

Why vibrant: tonalSpot gives a dusty rose primary (`#8E4955`) — the old dullness, in pink;
fidelity keeps the bright seed as the container in dark, a glaring slab on the night. Vibrant
gives a confident raspberry (`#BD0046`) on blush surfaces and a plum night in dark. AnKi
deliberately does **not** use wallpaper dynamic color: the lotus palette is the brand. The old
night-indigo seed (`#073165`, tonalSpot: slate blue `#425E91` on grey-blue surfaces) is gone; the
native splash keeps the night, in plum (`#1D1011`).

| Role | Light | Dark |
|------|-------|------|
| primary / onPrimary | `#BD0046` / `#FFFFFF` | `#FFB2BC` / `#670022` |
| primaryContainer / on | `#FFD9DD` / `#910034` | `#910034` / `#FFD9DD` |
| secondary / onSecondary | `#8E4955` / `#FFFFFF` | `#FFB2BC` / `#561D28` |
| secondaryContainer / on | `#FFD9DD` / `#72333E` | `#72333E` / `#FFD9DD` |
| tertiary / onTertiary | `#35618E` / `#FFFFFF` | `#9FCAFD` / `#003257` |
| tertiaryContainer / on | `#D1E4FF` / `#184974` | `#184974` / `#D1E4FF` |
| surface | `#FFF8F7` (blush) | `#1D1011` (plum night) |
| surfaceContainerLow / · / High | `#FFF0F1` `#FFE9EA` `#FDE2E4` | `#261819` `#2B1C1D` `#362628` |
| onSurface / onSurfaceVariant | `#261819` / `#574144` | `#F7DCDE` / `#DEBFC2` |
| error / onError | `#B02E00` / `#FFFFFF` (vermilion) | `#FFB5A0` / `#5F1500` |
| errorContainer / on | `#FFDBD1` / `#872100` | `#872100` / `#FFDBD1` |

Contrast facts (palette audit): onSurfaceVariant on surface 8.9 (L) / 10.9 (D), on a card
(`surfaceContainerHigh`) 7.7 / 8.4 → secondary text is safe; primary on surface 6.2 / 10.9;
filled button 6.5 / 7.7; every tonal container pair ≥ 7.2. `outline` on surface 4.3 / 5.8 → use
it for **meaningful** borders (inputs, selected outlines, 3:1 rule). `outlineVariant` is
1.6 / 2.0 → **decorative dividers only**, and the unselected chip's border: there the label and
icon identify the chip and the selection shows as a fill with a check, so the border is not
the cue. Error is **vermilion**, not M3's red: `AnKiColors.errorSeed` `#F4511E` (vibrant) puts it
24–25° of HCT hue away from the raspberry primary (HCT ≈ 10°), where M3's `#BA1A1A` sat at 15°
and read like it (a focused field and a field in error, « Annuler » beside « Effacer »). By day
the gap is clear (ΔE OKLab 5.6 → 8.4); **by night it stays small** (`#FFB5A0` vs `#FFB2BC`,
ΔE 2.5 → 4.1): at tone 80 the gamut caps vermilion's chroma, so a focused field and a field in
error still have near-identical outlines there. Error on surface 6.2 (L) / 10.9 (D), on a card
5.3 (L), onError 6.5 / 7.8, containers 7.3. The raspberry primary and plum red never stand for
an error, and an error is never shown by color alone: icon, label and placement carry it —
by night, they are the only cue.

### 3.2 Brand accents — what each color means

| Accent | Source | Means | Where |
|--------|--------|-------|-------|
| **Raspberry** = `primary` | lotus seed `#FFB6BF` | *Act here*, *this is selected* | The one filled action of a screen, links, focus, selected states, the S6 numerals |
| **Lotus** = `primaryContainer`, `secondaryContainer` | same seed | Warmth, the person, gentle emphasis | Tonal buttons, selected chips, the nav indicator, avatars' default tone |
| **Plum red** | `icon.png` blossoms `#FF1E32` | *The day itself* | J-0 only: the celebration gradient's end (hero, later the widget). Never a button outside J-0, never an error |
| **Cloud** = `tertiary*` | `icon.png` cloud `#C5DEFF` | Calm, information, time ahead | The hero gradient's end, informational cards and badges; never an action |
| **Moonlight** (lavender) | `lune.png` `#D0D0F8` → `AnKiColors.moonlight` | The moon | Orbit moon and arc, mascot, search highlight |
| **Blossom** | lotus `#F88898` → `AnKiColors.blossom` | The day's small marks | J-0 cake and orbit in agenda rows |
| **Mint** | leaf `#70D8B8` → `AnKiColors.success` | Done, « souhaité ✓ » | Success states, the wished check |
| **Gold** | stamens `#FFD849` | Festivity | Petal rain only |

Never paste these hex values into widgets: accents are derived as tonal pairs
(`ColorScheme.fromSeed(seedColor: accent, brightness: b)`) and exposed through `colorScheme` or the
`AnKiColors` ThemeExtension (flutter-recipes.md §2). Derived pairs guarantee ≥ 7:1 in both themes.

### 3.3 Color in use — the lotus distribution

This replaces the old 60-30-10 rule with ≤ 10 % of accent, which kept every screen but the hero
grey.
- **Canvas (~50 %)**: tinted surfaces — blush by day, plum night by night. Never a grey-blue
  neutral, never pure white or black.
- **Containers (~35 %)**: the brand's tonal containers carry the structure — cards on
  `surfaceContainer*`, selected chips and tonal buttons in lotus, information in cloud, each
  person's groups in their own tones (§3.5).
- **Vivid (~15 %)**: raspberry for *the* action and the selection, the hero gradient, the day's
  celebration. One filled primary button per screen.
- Run the logo test on every snapshot: when nothing but the canvas carries the brand, the screen
  is unfinished; when two vivid elements compete, it is loud.

### 3.4 Hero & celebration gradients (S1)

| Use | Light | Dark | Text on it |
|-----|-------|------|-----------|
| Hero (next birthday) | lotus → cloud `primaryFixedDim → tertiaryFixedDim` `#FFB2BC → #9FCAFD` (dawn on the pond) | berry → night blue `#7A1035 → #1E3F6E` (the pond at night; derived roles gave only 7.2:1) | L `onPrimaryFixed #400012` ≥ 10:1 · D `#FFE0E5` 8.7 / 8.6:1 |
| Celebration (J-0) | raspberry → plum red `#A8003D → #C0001D` (the plum seed `#FF1E32`'s vibrant primary) | `#7A0030 → #9B1B30` | L white 7.7 / 6.4:1 (4.9 at 85 %) · D `#FFE0E5` 9.1 / 6.6:1 (5.1 at 85 %) |

- Before the day the hero is pastel with dark text; only J-0 is vivid. The contrast between the
  waiting (pastel) and the day (vivid) is the story: never make the everyday hero vivid.
- A filled button on the celebration (« Souhaiter »): fill `onCelebration`, text and icon
  `onCelebrationAction` — the start of the gradient, ≥ 7.7:1 in both themes.
- Primary text on a gradient at 100 %. Secondary text **≥ 85 % opacity**, measured on both ends
  of each gradient in the palette audit (hero: 6.0–7.0:1 light, 6.7:1 dark). Never 70 %. A
  brighter plum end (`#D8243F`, prototype) failed at 85 % (3.9:1): the end stays a deep plum.
- Direction `topLeft → bottomRight`. Light: soft shadow tinted by `primary` (§7). Dark: no shadow.

### 3.5 Category colors

Each category tone comes from a seed in `LabelTones` (`lib/core/theme/label_tones.dart`, read
through `category.tones(context)` in `category_display.dart`), with values for both themes: the
main tone for dots, rings and chip icons (≥ 3:1 on the surface), the container pair for chips and
badges. Color is never the only cue: keep the icon + label.

A group's tone is the one picked at its creation among `LabelTones.pickable` (eight distinct
tones: no red, read as an error, nor yellow, brown or grey; the first free one is preselected),
else its predefined category's own (grey for « Autres »), else one derived from its id, so older
groups no longer share one ring.

### 3.6 Theme rules

**Both themes**: colors only from `colorScheme`, `AnKiColors` or `LabelTones` — no `Colors.*`, no hex, no
`isDark ? x : y` ternaries in widgets (put both values in the theme extension). Scrims =
`colorScheme.scrim` with alpha; shadows = `colorScheme.shadow` or `primary` with alpha.

**Dark** — the pond at night, not an inverted day:
- Plum night canvas; depth through tonal surfaces (`surfaceContainerLow → High`), not shadows
  (invisible on dark).
- Separate floating layers with a hairline `outlineVariant` at 40–60 % alpha.
- No pure black, no pure white text on large areas (`onSurface #F7DCDE`).
- Saturated accents only in small doses; large colored areas use container tones (berry
  `#910034`, night blue `#184974`).

**Light** — dawn on the pond:
- Blush canvas; layer with `surfaceContainerLow/High`, avoid white-on-white cards without a tone
  step.
- Shadows only for floating elements (nav pill, hero, floating button): tinted by `primary`,
  soft, low alpha.

## 4. Typography

**Outfit** (geometric, friendly, excellent numerals), bundled as static TTFs (OFL, weights 400,
500, 600, 700, 800 in `lib/assets/fonts/`) and applied by `ThemeData(fontFamily: 'Outfit')`:
real weights, so `style.copyWith(fontWeight:)` is safe within 400–800; correct offline; identical
in snapshots. A weight outside 400–800 needs its TTF added to the pubspec family first. Outfit has
no glyph for the non-breaking hyphen U+2011 (it draws « e_mail »): write « e-mail » with a plain
hyphen.

| M3 role | AnKi use | Weight |
|---------|----------|--------|
| displaySmall | Onboarding title, big countdown in celebration | 800 |
| headlineMedium / Small | Greeting name, screen titles, sheet titles | 700 |
| titleLarge | Hero name (the theme sets 600; the hero sets 800 with `copyWith`) | 600 · 800 |
| titleMedium | Names in list rows, section headers | 600–700 |
| bodyLarge / Medium | Content, descriptions, settings subtitles | 400 |
| labelLarge | Buttons, tabs, chips | 600 |
| labelMedium | Metadata (dates, countdown badges) | 500–600 |

Rules:
- **Minimum 12 sp** for any text, no exception left (the 11 sp published date went with
  `BookCard`, 2026-11-10).
- Sentence case. No ALL-CAPS overlines (hard to read, shouty); if an overline is needed:
  labelMedium, sentence case, `onSurfaceVariant` or 85 % on gradients.
- Tabular figures for anything that counts or aligns: `FontFeature.tabularFigures()`.
- Max two weights per component; hierarchy comes from size and color before weight.
- Body line height ≥ 1.4; line length ≤ ~60 characters on large screens.
- French typography: lowercase months and weekdays ("9 octobre"), no-break space
  (U+00A0; Outfit lacks the narrow U+202F) before `? ! : ;` (` `), « guillemets ».
  Format dates with `intl` `DateFormat` + locale, never by hand.

## 5. Shape

Soft, pebble-like — a petal, never a hard tile. Use **squircles** (`RoundedSuperellipseBorder` /
`ClipRSuperellipse`) for cards, tiles, hero and sheets: continuous corners read softer than
circular arcs (iOS-grade polish, unusual on Android — a quiet signature).

| Token | Radius | Use |
|-------|--------|-----|
| `AppRadii.xs` | 8 | Small badges, countdown chips inside tiles |
| `AppRadii.sm` | 12 | Thumbnails, tooltips, skeletons |
| `AppRadii.md` | 16 | Inner containers, image frames, date field |
| `AppRadii.lg` | 24 | Cards, list tiles, hero, dialogs |
| `AppRadii.xl` | 32 | Bottom-sheet top corners, nav pill |
| `StadiumBorder()` | full | Buttons, chips, search field, segmented controls, FAB-like adds |

Every radius comes from these tokens: the last raw ones, in `BookCard`, went with F5
(2026-10-25). Keep it that way.

## 6. Spacing & layout

4 dp baseline (M3), **8 dp grid for layout**. Tokens `AppSpacing`: `xxs 4 · xs 8 · sm 12 · md 16 ·
lg 24 · xl 32 · xxl 48`.
- Layout (screen gutters, gaps between blocks, sections): multiples of 8 — 8, 16, 24, 32, 48.
- Inside a component (icon ↔ label, chip padding, list-row rhythm): 4, 8, 12 allowed.
- Never 2, 6, 10, 14, 20 (except a 1–2 dp optical nudge, commented).
- Screen gutter **24** (*ma*: the content breathes). Dense grids may use 16.
- Agenda: month headers are list subheaders; their own top margin (16) is the gap, under the
  hero as between two months, with no extra `SizedBox` (exception to the section gap below).
- Section gap 24–32; card-to-card 12; content above the floating nav pill: pad by
  `MediaQuery.paddingOf(context).bottom` (the shell's `extendBody` puts the pill in it), never a
  constant.
- Thumb zone: primary actions in the bottom half or as a bottom CTA; top bar holds navigation and
  secondary actions. Sheets put the main CTA at the bottom, above the keyboard.

## 7. Depth & glass

- **Elevation** = tone first (surface containers), shadow second.
- Light shadow for floating elements: `colorScheme.primary` or `shadow` at 8–14 %, blur 24,
  offset (0, 8) — a blush glow rather than a grey smudge.
- Dark: no shadow; lift with a higher container tone + hairline border.
- **Glass** (nav pill, floating toolbars only): `BackdropFilter` blur σ 16–20 + fill
  `surfaceContainer` at 70–80 % (light) / 60–70 % (dark) + hairline `outlineVariant`. Never glass
  on text-heavy surfaces (legibility). Aligns with iOS 26 *Liquid Glass* and M3 Expressive floating
  toolbars without depending on either.

## 8. Motion

Use the M3 tokens shipped in Flutter (`Durations`, `Easing`) through `AppMotion` aliases.

| Intent | Duration | Curve |
|--------|----------|-------|
| Press / toggle / selection | `Durations.short3–short4` (150–200 ms) | `Easing.standard` |
| Element enters (sheet content, list item, snackbar) | `Durations.medium2` (300 ms) | `Easing.emphasizedDecelerate` |
| Element exits | `Durations.short4` (200 ms) | `Easing.emphasizedAccelerate` |
| Screen / container transform | `Durations.long2` (500 ms) | `Easing.emphasized…` |
| Drag, swipe, dismiss, playful bounce | spring `SpringDescription.withDurationAndBounce(duration: 350 ms, bounce: 0.15–0.25)` | — |

- Motion explains *where things come from and go*; it never decorates idle screens.
- Intros: stagger ≤ 40 ms per item, whole sequence ≤ 600 ms, and **controls are visible and
  interactive from the first frame**. Forms and sign-in pages have none: the page transition
  already says where they come from.
- Animate opacity/transform (cheap), not layout of text blocks.
- `MediaQuery.disableAnimationsOf(context)` → crossfade or no animation, no petals, no bounce.

## 9. Haptics

| Event | Haptic |
|-------|--------|
| Tab change, chip/segment selection, picker tick | `HapticFeedback.selectionClick()` |
| Primary action success (saved, imported, wished) | `HapticFeedback.lightImpact()` |
| Swipe crosses its action threshold, destructive action | `HapticFeedback.mediumImpact()` |
| Birthday celebration (S4), biometric unlock success | `HapticFeedback.mediumImpact()` once |
| Error | none (the message does the job) |

Haptics confirm, they never inform alone.

## 10. Icons & illustration

- Material Symbols **Rounded** (`Icons.*_rounded`). Outlined = inactive, filled = active/selected.
  Sizes 20 (dense) · 24 (default) · 32 (feature). Icon-only buttons always have a `tooltip`.
- Illustration style = the existing assets: flat pastel, rounded, no outlines, 2–3 tone shading,
  kawaii but restrained, in the icon's family (lotus, plum blossom, cloud, moon, mint leaves). New
  art must match or not exist. Max one illustration per screen.
- Avatars: photo if any; otherwise **initials** on a tonal container derived from the name
  (deterministic, like Google Contacts) — more human and recognizable than a generic person icon.

## 11. Voice & microcopy

AnKi talks like a thoughtful friend with a good memory: **warm, brief, concrete**.
- French template (`intl_fr.arb`), **« vous »** (current convention — changing to « tu » is a
  product decision). English mirrors the meaning, not the words.
- Lead with the person and the time: « Léa fête ses 30 ans demain », not « Anniversaire : Léa ».
- Numbers concrete and relative: « dans 3 jours », « aura 34 ans ».
- Buttons = verb (+ object): « Ajouter », « Souhaiter », « Importer mes contacts ». Never « OK ».
- Errors = what happened + what to do, no blame, no jargon: « Impossible d'enregistrer. Vérifiez
  votre connexion et réessayez. » — not « Erreur lors de l'enregistrement de l'anniversaire ».
- Prefer undo to « Êtes-vous sûr… ? ». Confirmations name the object and the consequence.
- Empty states invite: title (what's missing) + one line (why it's worth it) + CTA.
- Emoji: at most one, only for celebration (🎉 today), never in errors or system messages.
