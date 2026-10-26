# Flutter recipes — implementing AnKi's design system

Every snippet here was compiled and exercised against Flutter 3.47.6 (and 3.44.9) / Riverpod 3.4 (component
rendering checked in light, dark and 200 % text). Adapt names, keep the shapes.

## Contents
1. Shared components (`lib/core`)
2. The brand in `AppTheme`
3. Typography foundation — bundle Outfit
4. Delete with « Annuler » (undo)
5. Agenda grouped by time, sticky headers
6. Large-text reflow
7. Dates & countdown copy
8. Motion & haptics
9. Squircles
10. System bars, edge-to-edge, predictive back
11. Tests for UI changes

---

## 1. Shared components

Installed in `lib/` since roadmap step 1 (2026-10-12), each with its test under `test/core/`:
import them from `package:an_ki/core/...`, extend them there, never fork them per feature.

| File | Provides |
|------|----------|
| `lib/core/theme/app_tokens.dart` | `AppSpacing`, `AppRadii`, `AppMotion`, `context.reduceMotion`, `context.motion(d)` |
| `lib/core/theme/anki_colors.dart` | `AnKiColors` ThemeExtension (hero, celebration, blossom, success, moonlight, glass, shadow), `TonalColors.fromSeed/of`, `context.ankiColors` (safe fallback when the extension is missing) |
| `lib/core/theme/label_tones.dart` | `LabelTones.of(index, brightness)` — accessible tonal pair per user label (categories: `category.tones(context)`) |
| `lib/core/common/moon_phase.dart` | `MoonPhase(daysLeft:)` — signature S3 |
| `lib/core/common/anki_empty_state.dart` | `AnKiEmptyState` — illustration, title, message, primary/secondary CTA |
| `lib/core/common/skeleton_box.dart` | `SkeletonBox` — pulsing placeholder, static under reduce-motion |
| `lib/core/common/anki_avatar.dart` | `AnKiAvatar(name:, image:)` — photo or initials on a stable tonal color |
| `lib/core/common/bottom_bar.dart` | `BottomBar` (signature S5), the shell `Scaffold`'s `bottomNavigationBar` (`extendBody`): lists pad by `MediaQuery.paddingOf(context).bottom`, snackbars float above it |

`anki_colors_test.dart` locks the identity's promise: every brand text/background pair stays
≥ 4.5:1 in both themes. If a seed change breaks it, the test fails — fix the color, not the test.

## 2. The brand in `AppTheme`

Shipped in `lib/core/theme/themes.dart` (tested by `test/core/theme/themes_test.dart`): read it
rather than a copy. Its component themes carry the brand — stadium buttons at least 56 dp tall,
pebble squircles for cards and dialogs, filled inputs, bottom sheets with their drag handle and
`AppRadii.xl` top corners, floating snackbars, 48 dp minimum for text and segmented buttons, and
the `AnKiColors` extension. A per-widget `styleFrom` or radius override duplicates the theme:
delete it when you touch the widget (the leftovers are backlog F5). Flutter 3.44+ uses the
`*ThemeData` classes (`AppBarThemeData`, `InputDecorationThemeData`, `CardThemeData`,
`DialogThemeData`).

In widgets: `context.ankiColors.hero` (gradient), `.onHero`, `.blossom.container`… and
`Theme.of(context).colorScheme` for everything else. Sheets take their handle and shape from
`bottomSheetTheme`: never draw your own.

## 3. Typography foundation — bundle Outfit

Shipped (backlog F1, 2026-10-26) from `Outfitio/Outfit-Fonts@9027738`; kept as the reference for
adding a weight. Why: offline first launch, no runtime network call, and real weights.
Steps (downloading a font = ask the maintainer first):
1. Static TTFs from Google Fonts (OFL) — Outfit 300…900 — into `lib/assets/fonts/`, next to the
   app's other assets.
2. `pubspec.yaml`:
   ```yaml
   flutter:
     fonts:
       - family: Outfit
         fonts:
           - asset: lib/assets/fonts/Outfit-Regular.ttf
           - asset: lib/assets/fonts/Outfit-Medium.ttf
             weight: 500
           - asset: lib/assets/fonts/Outfit-SemiBold.ttf
             weight: 600
           - asset: lib/assets/fonts/Outfit-Bold.ttf
             weight: 700
           - asset: lib/assets/fonts/Outfit-ExtraBold.ttf
             weight: 800
   ```
3. `ThemeData(fontFamily: 'Outfit', …)`; remove `GoogleFonts.outfit…` from the theme (and the
   `google_fonts` dependency if unused). Text styles then come from the M3 type scale; tune
   weights per role in a `textTheme` copy (identity §4).
4. Snapshots switch from the Roboto stand-in to real Outfit automatically (fonts declared in
   pubspec are loaded by the tool).

## 4. Delete with « Annuler »

Gmail pattern, shipped in step 2: the person disappears at once, a snackbar offers undo, the write
happens only when the snackbar closes without undo.

- `pendingDeletionsProvider` (`birthday_provider.dart`): a session-scoped set of hidden ids;
  `birthdaysListProvider` leaves them out, so the hero, the agenda, the calendar and the search
  all hide the person at once.
- `deleteWithUndo(context, birthday)` (`widgets/birthday_deletion.dart`): hides, shows the
  snackbar (`persist: false`, 5 s, 10 s with TalkBack), then on any close but the action calls
  `BirthdayEditor.delete` and unhides once the write ends — the Firestore stream drops the
  document by itself, a failure makes it reappear and the home announces it.
- It reads everything before the snackbar closes, through
  `ProviderScope.containerOf(context, listen: false)`: the swiped row or the closed sheet is gone
  by then, its `WidgetRef` with it.
- Callers: the agenda row (`Dismissible` end-to-start — start-to-end stays free for a positive
  action), its TalkBack `CustomSemanticsAction`, the edit sheet's delete button. No dialog.
- Snackbars always render in the shell's root `Scaffold` (nested Scaffolds): the nav bar is that
  Scaffold's `bottomNavigationBar`, so floating snackbars sit above it.
- « Souhaité » (`widgets/birthday_wish.dart`) reuses the snackbar but writes at once and undoes
  with `unmarkWished` (`arrayRemove`): marking destroys nothing. It reads the messenger, the
  strings and TalkBack's state before the share sheet opens, the context may be gone after.

## 5. Agenda grouped by time, sticky headers

Shipped in step 2 — read the code rather than a copy:
- Rule: `features/birthday/domain/agenda.dart` — `agenda(today)` returns `AgendaSection`s
  (`AgendaSoon`, then `AgendaMonth(year, month)`), tested on the year boundary and 29 February.
- Wiring: `agendaProvider` (everyone but the hero's people), labels by `agendaPeriodLabel`
  (`DateFormat.MMMM`, `yMMMM` for another year, sentence case).
- Slivers: `AgendaSliver` (`widgets/agenda_list.dart`) — one `SliverMainAxisGroup` per section,
  each with a pinned `SliverPersistentHeader` whose extent follows the text scale.
- `PinnedHeaderSliver` pins at the very top and slides **under** a pinned `SliverAppBar`; the
  pinned `SliverPersistentHeader` stacks below it. Header background opaque
  (`colorScheme.surface`) so rows pass beneath.

## 6. Large-text reflow

Shipped in `next_birthday.dart` and `agenda_tile.dart`: beyond 150 %, avatar and number go on a
row above the name. The nav pill (`bottom_bar.dart`) puts icons above labels beyond 150 %, and
also as soon as a label, measured with `TextPainter`, wouldn't fit beside its icon
(« Anniversaires » at 130 % on a 360 or 393 dp phone): when the width decides, measure rather
than guess a threshold.

```dart
// Au-delà de 150 % de texte, empiler plutôt que compresser.
final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
final content = stacked
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Row(children: [avatar, const Spacer(), number]), identity],
      )
    : Row(children: [avatar, Expanded(child: identity), number]);
```
No `height:` around text; `minHeight` via `ConstrainedBox` if a block needs presence.
`SegmentedButton` labels wrap mid-word at 200 % (« Systè-me ») — beyond 1.5× prefer a vertical
`RadioGroup`/list of choices, or short labels with icons.

## 7. Dates & countdown copy

```dart
final locale = Localizations.localeOf(context).toLanguageTag();
DateFormat.MMMMd(locale).format(date);   // « 9 octobre » / "October 9"
DateFormat.yMMMMd(locale).format(date);  // « 9 octobre 1992 »
```
Never build dates by hand (`'${d.day}/${d.month}/${d.year}'`, month arrays). A `BirthDate`
without a year is formatted on a leap year (2000), so 29 February exists: use
`date.formatted(context)` (`birthday_display.dart`) rather than a new `DateTime`. Typed birth
dates: `BirthDateField` (mask, preview, errors) over the pure rules of `birth_date_input.dart`.
Counts use ICU plurals; reuse the existing keys (`countdownDays`, `heroAgeUnit`, `agendaLine`,
`inDays`) before adding one:
```json
"countdownDays": "{days, plural, =0{Aujourd'hui} =1{Demain} other{J-{days}}}",
"heroAgeUnit": "{age, plural, one{an} other{ans}}"
```

## 8. Motion & haptics

```dart
AnimatedSwitcher(
  duration: context.motion(AppMotion.enter),
  switchInCurve: AppMotion.enterCurve,
  switchOutCurve: AppMotion.exitCurve,
  child: KeyedSubtree(key: ValueKey(state), child: content),
)
```
- Drag/dismiss/bouncy feedback: `SpringDescription.withDurationAndBounce(duration:
  const Duration(milliseconds: 350), bounce: 0.2)` with `AnimationController.animateWith(
  SpringSimulation(spring, from, to, velocity))`.
- Haptics per identity §9; call them where the user action is handled, once.
- A one-shot celebration (`BlossomRain`, S4): an `AnimationController` started in
  `didChangeDependencies` unless `MediaQuery.disableAnimationsOf`, a `CustomPainter` repainting
  on it, `IgnorePointer` + `ExcludeSemantics`. Decide « play » once at mount, so marking it
  played mid-animation doesn't cut it.
- Never block input during an animation; long intros are skipped on reduce-motion.

## 9. Squircles

```dart
DecoratedBox(
  decoration: ShapeDecoration(
    gradient: context.ankiColors.hero,
    shadows: context.ankiColors.floatingShadow,
    shape: const RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
    ),
  ),
  child: …,
)
```
`Card(shape: …)`, `Material(shape: …)` and button `shape:` accept it too; clip images with
`ClipRSuperellipse`. Ink ripples: put an `InkWell` inside a `Material` with the same shape.

## 10. System bars, edge-to-edge, predictive back

- Android 15+ draws edge-to-edge: content under transparent bars, `SafeArea` on every screen,
  status-bar icon brightness from `AppBarThemeData.systemOverlayStyle`; screens without an
  `AppBar` wrap their body in `AnnotatedRegion<SystemUiOverlayStyle>`.
- The floating nav pill adds the bottom inset itself (`SafeArea(top: false)`); scrollables beneath
  it pad by its real height.
- Flutter's default Android page transition (3.44+) is `PredictiveBackPageTransitionsBuilder`; to
  get the system back-gesture preview, `android:enableOnBackInvokedCallback="true"` sits on
  `<application>` in `AndroidManifest.xml` (since 2026-10-24). No screen intercepts back
  (`PopScope`): if one must, use `PopScope` with `onPopInvokedWithResult`, never the
  deprecated `WillPopScope` (incompatible with predictive back).

## 11. Tests for UI changes

- Behaviour via `tester.pumpHarness(...)` (+ overrides from `test/support/fake_providers.dart`).
- Accessibility via `meetsGuideline(...)` and `find.bySemanticsLabel` (accessibility.md §7).
- Changed copy/icons: update the existing widget tests in the same change.
- Visual: snapshot tool before/after; contrast: palette audit. Goldens are not used in this repo
  (platform-dependent); the snapshot tool covers that need without committing images.
