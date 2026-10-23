# AnKi identity — « Jardin au clair de lune »

The source of truth for what makes a screen *look and feel like AnKi*. Every value below was
computed with `ColorScheme.fromSeed` (tonalSpot) on 2026-10-07 — identical on Flutter 3.44.9 and 3.47.6; if a seed changes,
re-run `scripts/palette_audit_test.dart` and update the tables.

## Contents
1. Concept · 2. Signature elements · 3. Color · 4. Typography · 5. Shape · 6. Spacing & layout ·
7. Depth & glass · 8. Motion · 9. Haptics · 10. Icons & illustration · 11. Voice & microcopy

---

## 1. Concept

**AnKi** (暗記, *learn by heart*) + **Kairos** (the right moment): never miss the moment that
matters to someone you love. The brand already exists in the assets — a smiling moon, lotus and
plum blossoms, soft clouds, a deep night-indigo seed (`#073165`) and a night splash (`#121318`).

The identity is a **moonlit garden**: Japanese-inspired calm (generous negative space, *ma*),
warmth (blossoms = celebration), precision (time, countdowns). Three adjectives to test every
screen against: **calm · warm · precise**. If a screen is loud, cold or vague, it's off-brand.

Benchmarks for the *feel*: Headspace/Calm (soft, reassuring), Things 3 (crafted minimalism),
Spotify (one accent used with intent), Google Calendar (clarity of time).

## 2. Signature elements

Originality lives **only** here — controls stay conventional. Use each one where listed, nowhere
else: a signature seen everywhere stops being one.

| # | Element | Where | Rules |
|---|---------|-------|-------|
| S1 | **Dusk / night hero gradient** | Next-birthday hero, celebration state, onboarding hero | Max one per screen. Light = dusk (`primary → tertiary`), dark = night (`primaryContainer → tertiaryContainer`), see §3.3. |
| S2 | **Moon mascot** (`AppAssets.moon`) | Empty states, onboarding, success/zero-inbox moments | Never in dense screens or lists. Max one per screen. Shines on dark — no white plate behind it. |
| S3 | **Moon-phase countdown** *(`lib/core/common/moon_phase.dart`)* | Next to "dans N jours" in hero and list rows | Waxing moon over the last 29 days, full moon = today; beyond 29 days an unlit disc. Always paired with text (decorative for TalkBack). On gradients pass `litColor: onHero`. |
| S4 | **Blossom celebration** *(`features/birthday/widgets/blossom_rain.dart`)* | Hero on the birthday itself (J-0) | Soft falling lotus/plum petals ≤ 2.5 s (2.4 s), once per person per day, `mediumImpact`. Skipped when reduce-motion is on. Never generic confetti. Tones `AnKiColors.petals`. |
| S5 | **Floating glass pill navigation** | Main tabs (`core/common/bottom_bar.dart`) | Blurred translucent pill, radius 32, content scrolls beneath. Labels must stay available to TalkBack. |
| S6 | **Big tabular numerals** | Countdown, age, counts | Outfit w800, `FontFeature.tabularFigures()`, letter-spacing −1, once Outfit is bundled (F1); until then the theme style at its native weight with tabular figures. One per card. |

## 3. Color

### 3.1 Base scheme — seed « Nuit » `#073165`, `DynamicSchemeVariant.tonalSpot`

Keep **tonalSpot**: `fidelity` was tested and rejected (light primary turns near-black `#001C42`
and tertiary turns brown `#351300`). AnKi deliberately does **not** use wallpaper dynamic color:
the night indigo *is* the brand.

| Role | Light | Dark |
|------|-------|------|
| primary / onPrimary | `#425E91` / `#FFFFFF` | `#ABC7FF` / `#0C305F` |
| primaryContainer / on | `#D7E3FF` / `#284677` | `#284677` / `#D7E3FF` |
| secondaryContainer / on | `#DAE2F9` / `#3E4759` | `#3E4759` / `#DAE2F9` |
| tertiary / onTertiary | `#705574` / `#FFFFFF` | `#DDBCE0` / `#3F2844` |
| tertiaryContainer / on | `#FAD8FD` / `#573E5C` | `#573E5C` / `#FAD8FD` |
| surface | `#F9F9FF` | `#111318` (≈ splash `#121318`) |
| surfaceContainerLow / · / High / Highest | `#F3F3FA` `#EDEDF4` `#E7E8EE` `#E2E2E9` | `#191C20` `#1E2025` `#282A2F` `#33353A` |
| onSurface / onSurfaceVariant | `#191C20` / `#44474E` | `#E2E2E9` / `#C4C6D0` |
| outline / outlineVariant | `#74777F` / `#C4C6D0` | `#8E9099` / `#44474E` |
| error | `#BA1A1A` | `#FFB4AB` |

Contrast facts (palette audit): onSurfaceVariant on surface 8.9 (L) / 10.9 (D) → secondary text
is safe. `outline` on surface 4.3 / 5.8 → use it for **meaningful** borders (inputs, selected
outlines, 3:1 rule). `outlineVariant` is 1.6 / 2.0 → **decorative dividers only**.

### 3.2 Brand accents — from the illustrations

Sampled from `icon.png` / `lune.png`. Never paste these hex values into widgets: derive tonal pairs
with `ColorScheme.fromSeed(seedColor: accent, brightness: b)` and expose them through the
`AnKiColors` ThemeExtension (flutter-recipes.md §2). Derived roles guarantee ≥ 7:1 in both themes.

| Accent | Seed | Meaning | Light: main · container/on | Dark: main · container/on |
|--------|------|---------|----------------------------|---------------------------|
| **Blossom** (lotus) | `#F88898` | Celebration, "today", love | `#8E4954` · `#FFD9DC`/`#72333D` | `#FFB2BB` · `#72333D`/`#FFD9DC` |
| **Mint** (leaf) | `#70D8B8` | Success, "wished ✓", done | `#136B55` · `#A3F2D7`/`#00513F` | `#88D6BB` · `#00513F`/`#A3F2D7` |
| **Moonlight** (lavender) | `#D0D0F8` | Calm highlights, onboarding, moon motif | `#565992` · `#E1E0FF`/`#3F4178` | `#BFC1FF` · `#3F4178`/`#E1E0FF` |
| Plum red | `#F81830` | Illustration only — never UI (reads as error) | — | — |
| Cloud | `#C0D8F8` | Illustration only | — | — |

**60-30-10**: ~60 % surfaces, ~30 % containers/neutral tones, ≤ 10 % accent (primary actions +
the one "moment" per screen). Spotify's rule: the accent means *act here* or *this matters now*.

### 3.3 Hero & celebration gradients (S1)

| Use | Light | Dark | Text on it |
|-----|-------|------|-----------|
| Hero (next birthday) | `primary → tertiary` `#425E91 → #705574` (dusk) | `primaryContainer → tertiaryContainer` `#284677 → #573E5C` (night sky) | L: `onPrimary` · D: `onPrimaryContainer` |
| Celebration (J-0) | `primary → blossom.main` `#425E91 → #8E4954` | `primaryContainer → blossom.container` `#284677 → #72333D` | L: `#FFFFFF` · D: `blossom.onContainer` |

- A filled button on the celebration (« Souhaiter »): fill `onCelebration`, text and icon
  `onCelebrationAction` — the start of the gradient, ≥ 6.5:1 in both themes.
- Primary text on the gradient at 100 % (6.5:1 L, 7.3:1 D). Secondary text **≥ 85 % opacity**
  (5.2 L, 5.8 D). **Never 70 %**: it measures 4.1 (L) / 4.5 (D, 4.48) — fails AA (palette audit).
- Dark hero = containers (night sky), always: `primary → tertiary` in dark is a pastel slab that
  glares on the night background.
- Direction `topLeft → bottomRight`. Light: soft tinted shadow (see §7). Dark: no shadow.

### 3.4 Category colors

Each category tone comes from a seed in `LabelTones` (`lib/core/theme/label_tones.dart`, read
through `category.tones(context)` in `category_display.dart`), with values for both themes: the
main tone for dots, rings and chip icons (≥ 3:1 on the surface), the container pair for chips and
badges. Color is never the only cue: keep the icon + label.

### 3.5 Theme rules

**Both themes**: colors only from `colorScheme`, `AnKiColors` or `LabelTones` — no `Colors.*`, no hex, no
`isDark ? x : y` ternaries in widgets (put both values in the theme extension). Scrims =
`colorScheme.scrim` with alpha; shadows = `colorScheme.shadow` with alpha.

**Dark** — night, not inverted day:
- Depth through tonal surfaces (`surfaceContainerLow → Highest`), not shadows (invisible on dark).
- Separate floating layers with a hairline `outlineVariant` at 40–60 % alpha.
- No pure black, no pure white text on large areas (`onSurface #E2E2E9`).
- Saturated accents only in small doses; large colored areas use container tones.

**Light** — cool, airy paper:
- Layer with `surfaceContainerLow/High` on `surface`; avoid white-on-white cards without a tone step.
- Shadows only for floating elements (nav pill, hero, FAB): tinted, soft, low alpha.

## 4. Typography

**Outfit** (geometric, friendly, excellent numerals). Today it's fetched at runtime by
`google_fonts` → offline first launch shows the fallback font, and `style.copyWith(fontWeight:)`
renders a **faux bold** (google_fonts registers one family per weight). Target: bundle Outfit
static TTFs (OFL) as a pubspec family and use `ThemeData(fontFamily: 'Outfit')` (backlog F1).

| M3 role | AnKi use | Weight |
|---------|----------|--------|
| displaySmall | Onboarding title, big countdown in celebration | 800 |
| headlineMedium / Small | Greeting name, screen titles, sheet titles | 700 |
| titleLarge | Hero name | 800 |
| titleMedium | Names in list rows, section headers | 600–700 |
| bodyLarge / Medium | Content, descriptions, settings subtitles | 400 |
| labelLarge | Buttons, tabs, chips | 600 |
| labelMedium | Metadata (dates, countdown badges) | 500–600 |

Rules:
- **Minimum 12 sp** for any text (the one exception left: `labelSmall`, 11 sp, for the published
  date in `book_card.dart`).
- Sentence case. No ALL-CAPS overlines (hard to read, louder than "calm"); if an overline is
  needed: labelMedium, sentence case, `onSurfaceVariant` or 85 % on gradients.
- Tabular figures for anything that counts or aligns: `FontFeature.tabularFigures()`.
- Max two weights per component; hierarchy comes from size and color before weight.
- Body line height ≥ 1.4; line length ≤ ~60 characters on large screens.
- French typography: lowercase months and weekdays ("9 octobre"), narrow no-break space before
  `? ! : ;` (` `), « guillemets ». Format dates with `intl` `DateFormat` + locale, never by hand.

## 5. Shape

Soft, pebble-like. Use **squircles** (`RoundedSuperellipseBorder` / `ClipRSuperellipse`) for
cards, tiles, hero and sheets: continuous corners read calmer than circular arcs (iOS-grade
polish, unusual on Android — a quiet signature).

| Token | Radius | Use |
|-------|--------|-----|
| `AppRadii.xs` | 8 | Small badges, countdown chips inside tiles |
| `AppRadii.sm` | 12 | Calendar cells, thumbnails, tooltips |
| `AppRadii.md` | 16 | Inner containers, image frames, date field |
| `AppRadii.lg` | 24 | Cards, list tiles, hero, dialogs |
| `AppRadii.xl` | 32 | Bottom-sheet top corners, nav pill |
| `StadiumBorder()` | full | Buttons, chips, search field, segmented controls, FAB-like adds |

Raw radii remain only in the screens of backlog F5 (12/16/24 written by hand, and an off-token 28
in `AnKiTextField`): migrate what you touch.

## 6. Spacing & layout

4 dp baseline (M3), **8 dp grid for layout**. Tokens `AppSpacing`: `xxs 4 · xs 8 · sm 12 · md 16 ·
lg 24 · xl 32 · xxl 48`.
- Layout (screen gutters, gaps between blocks, sections): multiples of 8 — 8, 16, 24, 32, 48.
- Inside a component (icon ↔ label, chip padding, list-row rhythm): 4, 8, 12 allowed.
- Never 2, 6, 10, 14, 20 (except a 1–2 dp optical nudge, commented).
- Screen gutter **24** (*ma*: calm needs air). Dense grids (calendar) may use 16.
- Section gap 24–32; card-to-card 12; content above the floating nav pill: pad by
  `MediaQuery.paddingOf(context).bottom` (the shell's `extendBody` puts the pill in it), never a
  constant.
- Thumb zone: primary actions in the bottom half or as a bottom CTA; top bar holds navigation and
  secondary actions. Sheets put the main CTA at the bottom, above the keyboard.

## 7. Depth & glass

- **Elevation** = tone first (surface containers), shadow second.
- Light shadow for floating elements: `colorScheme.shadow` at 8–12 %, blur 24, offset (0, 8);
  the hero may tint its shadow with `primary` at ≤ 20 %.
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
  kawaii but restrained. New art must match or not exist. Max one illustration per screen.
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
