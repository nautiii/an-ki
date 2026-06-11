# UI/UX Guidance

## Core Principles
* **Minimalism**: Every element must serve a clear purpose.
* **Affordance**: Use M3 elevations and states for interactivity.
* **Consistency**: Use standardized widgets from `lib/core/common/`.

## Layout & Grid
* **8dp Grid**: All spacing/padding MUST be multiples of 8 (`Gap(8)`, `Padding(24)`).
* **Safe Areas**: Mandatory `SafeArea` usage for notches/home indicators.
* **Lists**: Use `AlwaysScrollableScrollPhysics`. Always provide informative Empty States.

## Material 3 (M3)
* **Theming**: No hardcoded colors. Use `Theme.of(context).colorScheme.role`.
* **Surfaces**: Use `surfaceContainerHigh`/`Low` instead of `Colors.white`.
* **Icons**: Use `Rounded` Material variant.
* **Typography**: Use M3 scales (`labelLarge`: buttons, `titleMedium`: headers, `bodyMedium`: text).

## Components & Interactions
* **Dismissible**: Wrap in `ClipRRect` if tile is rounded. Background color must match action (e.g., `error`).
* **Haptics**: `HapticFeedback.lightImpact()` on success or primary actions.
* **SnackBars**: Floating behavior with rounded corners.
* **Transitions**: `AnimatedSwitcher` for state changes; `Hero` for image transitions.

## Accessibility & Validation
* **Touch Targets**: Minimum 48x48dp.
* **Semantics**: Use `Semantics`/`ExcludeSemantics` for screen readers.
* **Contrast**: Ensure high contrast ratios.
* **Forms**: Inline validation via `errorText`. Disable buttons during load/invalid state.
* **Loading**: `Shimmer` for lists; overlay spinners only for blocking actions.
