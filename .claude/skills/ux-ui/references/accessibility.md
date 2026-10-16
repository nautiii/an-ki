# Accessibility — AnKi standard

Target: **WCAG 2.2 AA** + Android/Material guidance. Birthday reminders are used by every age —
grandparents with large text, people who rely on TalkBack, one-handed use in a hurry. An
accessibility failure is a bug, not polish.

## Contents
1. Requirements · 2. Flutter toolbox · 3. Large text · 4. Color & contrast · 5. Motion, time,
haptics · 6. Focus & forms · 7. Testing

---

## 1. Requirements

| Area | Requirement |
|------|-------------|
| Text contrast | ≥ 4.5:1; large text (≥ 24 px, or ≥ 18.66 px bold) ≥ 3:1 |
| Non-text contrast | Meaningful icons, input borders, focus rings, state indicators, dots ≥ 3:1 (WCAG 1.4.11) |
| Touch targets | ≥ 48×48 dp, ≥ 8 dp between targets (the visual can be smaller, the hit area can't) |
| Text size | Min 12 sp; works at **200 %** system font scale without loss of content or overlap |
| Labels | Every interactive element has an accessible name; icon-only → `tooltip` |
| Color | Never the only carrier of meaning (selected, category, error, today) |
| Motion | Respects reduce-motion; nothing flashes > 3×/s |
| Time | No action requires speed; undo windows ≥ 4 s, persistent for screen-reader users |
| Structure | Headers marked, reading order = visual order, one announcement per logical item |

## 2. Flutter toolbox

- **Icon buttons**: `IconButton(tooltip: context.l10n.settings, …)` — the tooltip is the label.
- **Custom tappables**: prefer a real button or `InkWell` inside `Material` (ripple, focus,
  semantics) over `GestureDetector`. If custom: `Semantics(button: true, label: …, onTapHint: …)`.
- **Rows that read as one sentence**: build the phrase explicitly and hide the parts —
  ```dart
  Semantics(
    button: true,
    label: context.l10n.birthdayRowA11y(name, age, countdown), // « Léa Martin, aura 30 ans, demain »
    child: ExcludeSemantics(child: row),
  )
  ```
  (`MergeSemantics` is fine when the visual order already reads well.)
- **Decorative**: `Image.asset(…, excludeFromSemantics: true)`, `ExcludeSemantics` around
  ornaments (moon phase S3, petals S4, gradients).
- **Headers**: `Semantics(header: true, child: Text(sectionTitle))`.
- **Selection**: chips/segments/switches expose it natively; custom tabs →
  `Semantics(selected: isSelected, inMutuallyExclusiveGroup: true, …)`.
- **Swipe-only actions** are invisible to TalkBack → `Semantics(customSemanticsActions: {
  CustomSemanticsAction(label: l10n.delete): onDelete, … })` and duplicate them in a menu.
- **Announcements** for async results not otherwise visible:
  `SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context))`
  (`announce` is deprecated since 3.35). Live values: `Semantics(liveRegion: true)`.
- **Reading order**: `FocusTraversalGroup` + `OrderedTraversalPolicy`, or
  `Semantics(sortKey: OrdinalSortKey(n))` when layout order differs from logical order.

## 3. Large text (200 %)

- **Never fix a height around text.** Use padding + `ConstrainedBox(minHeight:)`. (Today: hero
  card `height: 110`, search bar `height: 48` → overflow at 200 %.)
- Text in a `Row` → `Expanded`/`Flexible`. Titles next to an action (sheet header) → title in
  `Expanded` with `maxLines: 2`.
- Ellipsis only for secondary text whose full value is reachable elsewhere.
- **Reflow** instead of shrinking: when `MediaQuery.textScalerOf(context).scale(16) / 16 > 1.5`,
  switch horizontal compositions to vertical (e.g. hero: big number under the name).
- Clamp only tiny decorative labels (badges) with
  `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: …)`; never body text or buttons.
- Screens must scroll when content can exceed the viewport (auth screen at 360×640 today).
- Verify with the snapshot variants `light-text200` and `compact-360x640`.

## 4. Color & contrast

- Compute, don't eyeball: `scripts/palette_audit_test.dart` blends alpha onto the background and
  prints the real ratio for light and dark.
- **Alpha text is a trap**: `onPrimary` at 70 % on the hero = 4.1 (L) / 3.9 (D). Use ≥ 85 % or a
  dedicated role.
- **Gradients**: check both ends (the audit has hero start/end pairs).
- `outlineVariant` (1.6–2:1) is for decoration; borders that define a control use `outline`.
- Pair color with a second cue: checkmark/filled tone for selected chips, icon + label for
  categories, icon + text for errors, ring + bold for "today".

## 5. Motion, time, haptics

- `MediaQuery.disableAnimationsOf(context)` → durations to zero or a simple crossfade; skip
  petals, bounces, staggered intros, parallax.
- Undo snackbars: **since Flutter 3.44 a `SnackBar` with an `action` persists by default**
  (`persist` defaults to `action != null`). For undo set `persist: false` and
  `duration: 5 s`; with TalkBack/VoiceOver on (`accessibleNavigation`) Flutter keeps snackbars with
  actions from timing out — good, keep it.
- Haptics never carry information alone (many users disable them).

## 6. Focus & forms

- Fields have a visible `labelText` (hints disappear on typing), `keyboardType`,
  `textInputAction` (`next` … `done`), `autofillHints`, `textCapitalization` for names.
- Errors inline (`errorText`), specific (« Indiquez au moins le jour et le mois »), announced;
  don't hide the error text (today `AnKiTextField` zeroes `errorStyle` and draws its own text —
  make sure the error stays in semantics).
- Opening a sheet moves focus inside (autofocus first field or title); closing returns focus.
- Keep M3 focus indicators; never remove overlay/focus colors.

## 7. Testing

**Widget tests** (behaviour + guidelines) — `TestHarness` does not apply `AppTheme`, so contrast
there checks the default theme; real-theme contrast is the job of the palette audit + snapshots.

```dart
testWidgets('header actions are accessible', (tester) async {
  final semantics = tester.ensureSemantics();
  await tester.pumpHarness(Header(userName: 'Camille', onOpenSettings: () {}));
  await tester.pumpAndSettle();

  expect(find.bySemanticsLabel('Paramètres'), findsOneWidget);
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  semantics.dispose();
});
```

**Snapshot audit** (`scripts/ui_snapshot_test.dart`) — tap targets, labels, contrast heuristic,
layout overflow at 200 % and 360×640, light and dark, with the real theme.

**Manual pass on a device** before shipping a redesign (commands: device skill,
`references/recipes.md` §5):
1. TalkBack: swipe through the screen — each element announced once, meaningful, in visual order;
   every action reachable (including swipe actions via the actions menu).
2. Font size and display size at maximum.
3. Dark theme; « Supprimer les animations » on (Accessibilité).
4. One-handed: primary action reachable with the thumb.
