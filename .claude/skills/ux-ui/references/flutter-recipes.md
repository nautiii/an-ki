# Flutter recipes — implementing AnKi's design system

Every snippet here was compiled and exercised against Flutter 3.47.6 (and 3.44.9) / Riverpod 3.4 (component
rendering checked in light, dark and 200 % text). Adapt names, keep the shapes.

## Contents
1. Shared components (`lib/core`)
2. Wire the brand into `AppTheme`
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

## 2. Wire the brand into `AppTheme`

Target shape of `AppTheme._buildTheme` (`lib/core/theme/themes.dart`). Component themes remove
ad-hoc styling from widgets: once they exist, delete per-widget `styleFrom`/radius overrides.
Flutter 3.44+ uses the `*ThemeData` classes (`AppBarThemeData`, `InputDecorationThemeData`,
`CardThemeData`, `DialogThemeData`).

```dart
static ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
  );
  const pebble = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
  );
  const buttonPadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.lg,
    vertical: AppSpacing.md,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // fontFamily: 'Outfit', ← une fois la police embarquée (§3) ; d'ici là, garder textTheme actuel.
    extensions: [AnKiColors.from(scheme)],
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: buttonPadding,
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 56),
        padding: buttonPadding,
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: pebble,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: scheme.surfaceContainerLow,
      shape: const RoundedSuperellipseBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    dialogTheme: const DialogThemeData(shape: pebble),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: AppSpacing.sm,
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
  );
}
```

Then in widgets: `context.ankiColors.hero` (gradient), `.onHero`, `.blossom.container`… and
`Theme.of(context).colorScheme` for everything else. With the theme sheet in place, bottom sheets
get their drag handle and shape for free — remove the hand-made handles/containers.

## 3. Typography foundation — bundle Outfit

Why: offline first launch, no runtime network call, and real weights (`copyWith(fontWeight:)` on a
google_fonts style only fakes bold). Steps (downloading the font = ask the maintainer first):
1. Static TTFs from Google Fonts (OFL) — Outfit 300…900 — into `assets/fonts/`.
2. `pubspec.yaml`:
   ```yaml
   flutter:
     fonts:
       - family: Outfit
         fonts:
           - asset: assets/fonts/Outfit-Regular.ttf
           - asset: assets/fonts/Outfit-Medium.ttf
             weight: 500
           - asset: assets/fonts/Outfit-SemiBold.ttf
             weight: 600
           - asset: assets/fonts/Outfit-Bold.ttf
             weight: 700
           - asset: assets/fonts/Outfit-ExtraBold.ttf
             weight: 800
   ```
3. `ThemeData(fontFamily: 'Outfit', …)`; remove `GoogleFonts.outfit…` from the theme (and the
   `google_fonts` dependency if unused). Text styles then come from the M3 type scale; tune
   weights per role in a `textTheme` copy (identity §4).
4. Snapshots switch from the Roboto stand-in to real Outfit automatically (fonts declared in
   pubspec are loaded by the tool).

## 4. Delete with « Annuler »

Gmail pattern: the item disappears at once, a snackbar offers undo, the write happens only when
the snackbar closes without undo. Logic in the Notifier, the widget only triggers it.

```dart
// birthday_provider.dart — état
class BirthdayState {
  // … champs existants
  /// Anniversaires masqués en attendant la fin du délai « Annuler ».
  final Set<String> pendingDeletionIds; // défaut : const {} (+ copyWith)
}

// BirthdayNotifier
void stageDeletion(String birthdayId) {
  state = state.copyWith(
    pendingDeletionIds: {...state.pendingDeletionIds, birthdayId},
  );
}

void undoDeletion(String birthdayId) {
  state = state.copyWith(
    pendingDeletionIds: {...state.pendingDeletionIds}..remove(birthdayId),
  );
}

/// Supprime pour de bon ; en cas d'échec l'élément réapparaît (échec visible).
Future<bool> commitDeletion(String uid, String birthdayId) async {
  try {
    await _repository.deleteBirthday(uid, birthdayId);
    return true;
  } on Object {
    return false;
  } finally {
    if (ref.mounted) undoDeletion(birthdayId);
  }
}

// Provider dérivé : les listes visibles excluent les suppressions en attente.
final birthdaysListProvider = Provider<List<Birthday>>((ref) {
  final state = ref.watch(birthdayProvider);
  return state.birthdays
      .where((b) => !state.pendingDeletionIds.contains(b.id))
      .toList();
});
```

```dart
// Widget (ex. ContactTile) — déclenché par Dismissible.onDismissed ou un menu.
void _deleteWithUndo(BuildContext context, WidgetRef ref, Birthday b) {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return;
  // Lu avant l'async : le notifier survit à ce widget, pas `ref`.
  final notifier = ref.read(birthdayProvider.notifier);
  final l10n = context.l10n;
  HapticFeedback.mediumImpact();
  notifier.stageDeletion(b.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
          SnackBar(
            content: Text(l10n.birthdayDeleted('${b.name} ${b.surname}')),
            persist: false, // depuis 3.44 : avec une action, un SnackBar persiste sinon
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: l10n.undo, // à ajouter : « Annuler » / "Undo"
              onPressed: () => notifier.undoDeletion(b.id),
            ),
          ),
        )
        .closed
        .then((reason) {
          if (reason != SnackBarClosedReason.action) {
            notifier.commitDeletion(uid, b.id);
          }
        });
}
```

Remove the confirmation dialog from the swipe. Keep `Dismissible(direction: endToStart)` and add
`Semantics(customSemanticsActions: {CustomSemanticsAction(label: l10n.delete): …})` so TalkBack
users can delete too. With TalkBack on, Flutter keeps action snackbars open — fine.

## 5. Agenda grouped by time, sticky headers

```dart
enum AgendaBucket { today, thisWeek, thisMonth, later }

AgendaBucket bucketFor(int daysUntilNext) => switch (daysUntilNext) {
  0 => AgendaBucket.today,
  <= 7 => AgendaBucket.thisWeek,
  <= 31 => AgendaBucket.thisMonth,
  _ => AgendaBucket.later,
};

/// Anniversaires visibles groupés par période, dans l'ordre chronologique.
final agendaProvider = Provider<Map<AgendaBucket, List<Birthday>>>((ref) {
  final birthdays = [...ref.watch(filteredBirthdaysProvider)]
    ..sort((a, b) => a.daysUntilNext.compareTo(b.daysUntilNext));
  final agenda = <AgendaBucket, List<Birthday>>{};
  for (final birthday in birthdays) {
    (agenda[bucketFor(birthday.daysUntilNext)] ??= []).add(birthday);
  }
  return agenda;
});
```

```dart
CustomScrollView(
  slivers: [
    // SliverAppBar.large (salutation), héros, puis :
    for (final MapEntry(key: bucket, value: people) in agenda.entries)
      SliverMainAxisGroup(
        slivers: [
          PinnedHeaderSliver(child: _BucketHeader(bucket: bucket)), // Semantics(header: true)
          SliverList.builder(
            itemCount: people.length,
            itemBuilder: (context, i) => ContactTile(birthday: people[i]),
          ),
        ],
      ),
    // Espace sous la barre flottante : hauteur de la barre + marge + safe area, calculée.
  ],
)
```

Labels via l10n: « Aujourd'hui », « Cette semaine », « Dans le mois », « Plus tard ». The header
background must be opaque (`colorScheme.surface`) so pinned headers don't overlap rows.

## 6. Large-text reflow

```dart
// Au-delà de 150 % de texte, empiler plutôt que compresser.
final stacked = MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5;
final content = stacked
    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, number])
    : Row(children: [Expanded(child: identity), const SizedBox(width: AppSpacing.md), number]);
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
Never build dates by hand (`'${d.day}/${d.month}/${d.year}'`, month arrays). Countdown with ICU
plurals in the ARB files:
```json
"countdown": "{days, plural, =0{Aujourd'hui} =1{Demain} other{Dans {days} jours}}",
"turningAge": "{age, plural, =1{aura 1 an} other{aura {age} ans}}"
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
  get the system back-gesture preview add `android:enableOnBackInvokedCallback="true"` on
  `<application>` in `AndroidManifest.xml` (currently absent).

## 11. Tests for UI changes

- Behaviour via `tester.pumpHarness(...)` (+ overrides from `test/support/fake_providers.dart`).
- Accessibility via `meetsGuideline(...)` and `find.bySemanticsLabel` (accessibility.md §7).
- Changed copy/icons: update the existing widget tests in the same change.
- Visual: snapshot tool before/after; contrast: palette audit. Goldens are not used in this repo
  (platform-dependent); the snapshot tool covers that need without committing images.
