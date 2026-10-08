---
paths:
  - "lib/features/*/screens/**"
  - "lib/features/*/widgets/**"
  - "lib/features/home/**"
  - "lib/app/shell/**"
  - "lib/core/common/**"
  - "lib/core/theme/**"
  - "lib/core/animations/**"
---

# UI code — screens, widgets, theme

Non-negotiables for any widget change, even a one-line fix. Design work (new screen or flow,
redesign, states, motion, copy) goes through the ux-ui skill: identity, patterns, recipes,
ready-made components and the snapshot tool live there.

## Rendering

- Widgets render state and forward intents: no repository or backend SDK import, no business
  rule in `build`, nothing started from `build` (no future, no controller creation).
- `ref.watch` in `build`, `ref.read` in callbacks, `ref.listen` for one-off effects (snackbar,
  navigation); narrow rebuilds with `select`. Never `ref.read(provider.future)` to load data.
- Render an `AsyncValue` in this order: error (`hasError` first — a provider being retried is
  loading *with* an error), empty, data, loading.
- Every state is designed: loading = skeleton, empty = message + call to action, error = what
  happened + how to recover + retry. A blank area or a bare spinner is a bug.
- `core/common` widgets stay dumb: parameters and callbacks, no provider, no feature import.
- Text controllers and focus live in the widget's `State`; shared state lives in providers
  (no `setState` for it, no nested `StreamBuilder`/`FutureBuilder`).

## Style

- Colors only from `Theme.of(context).colorScheme` (and `context.ankiColors` once installed from
  the ux-ui assets): no `Colors.*`, no hex, no `isDark ? a : b` in widgets.
- Text styles from `Theme.of(context).textTheme`; 12 sp minimum; sentence case, no all-caps.
- Layout spacing on the 8 dp grid (4, 8, 12 inside a component); never 2, 6, 10, 14 or 20.
  Use `AppSpacing`, `AppRadii` and `AppMotion` once installed; migrate ad-hoc values only in what
  you touch.
- Icons `Icons.*_rounded`; outlined = inactive, filled = selected.
- Every string from `context.l10n`; dates with `DateFormat` and the locale, never by hand.
- Past ~300 lines, extract private widget classes (`_Section`), not methods returning widgets.

## Accessibility — failures are bugs

- Touch targets ≥ 48×48 dp. Icon-only buttons have a `tooltip`. Custom tappables are real buttons
  or an `InkWell`, not a bare `GestureDetector`, or carry `Semantics(button: true, label: …)`.
- No fixed height around text; text in a `Row` sits in `Expanded`/`Flexible`; content that can
  exceed the viewport scrolls. Layouts hold at 200 % text and at 360×640.
- Color is never the only cue; decorative images and ornaments are excluded from semantics.
- Swipe actions also exist as semantic actions; prefer undo to a confirmation dialog.
- Forms: visible `labelText`, inline specific `errorText`, submit disabled while the draft is
  invalid or an awaited operation runs.
- Motion follows `MediaQuery.disableAnimationsOf(context)`; haptics confirm an action
  (`selectionClick`, `lightImpact`), they never carry information alone.

## Flutter 3.47 specifics

- Android 15+ is edge-to-edge: `SafeArea` on every screen.
- A `SnackBar` with an action persists by default since 3.44: pass `persist: false` for undo.
- Theme classes are `AppBarThemeData`, `CardThemeData`, `DialogThemeData`,
  `InputDecorationThemeData`. `GoogleFonts.outfit(…)` + `copyWith(fontWeight:)` renders a faux
  bold: use theme styles at their native weight until Outfit is bundled.

## Tests

Widget tests with `tester.pumpHarness` (see `tests.md`); changed copy or icons → update their tests
in the same change. Look and contrast are checked with the ux-ui snapshot tool, not goldens.
