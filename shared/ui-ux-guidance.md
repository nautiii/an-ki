# UI/UX Guidance

## Core Principles

* **Minimalism**: every element serves a clear purpose.
* **Consistency**: reuse standardized widgets from `lib/core/common/`.
* **Zero empty states**: always show an informative placeholder or CTA.

## Layout

* **8dp grid**: all spacing/padding is a multiple of 8 (`Gap(8)`, `Padding(24)`).
* **Safe areas**: `SafeArea` is mandatory.
* **Lists**: `AlwaysScrollableScrollPhysics`.

## Material 3

* **Colors**: no hardcoded colors — `Theme.of(context).colorScheme.role`.
* **Surfaces**: `surfaceContainerHigh`/`Low`, never `Colors.white`.
* **Icons**: `Rounded` variant. **Typography**: M3 scales (`labelLarge` buttons, `titleMedium`
  headers, `bodyMedium` text).

## Interactions

* **Dismissible**: wrap rounded tiles in `ClipRRect`; background color matches the action (e.g.
  `error`).
* **Haptics**: `HapticFeedback.lightImpact()` on primary/success actions.
* **SnackBars**: floating, rounded.
* **Transitions**: `AnimatedSwitcher` for state changes; `Hero` for images.

## Accessibility & forms

* **Touch targets**: min 48×48dp. **Semantics**: `Semantics`/`ExcludeSemantics` for screen readers;
  ensure high contrast.
* **Forms**: inline `errorText`; disable buttons while loading/invalid (validate at UI before
  calling Notifiers).
* **Loading**: `Shimmer` for lists; overlay spinners only for blocking actions.
