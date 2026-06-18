# Global Anti-Patterns & Domain Rules

## Anti-Patterns

* No logic in `build()` (no controller instantiation / future launching).
* No direct Firebase in UI — data flows through Providers.
* No `setState` for shared state — use Riverpod.
* No nested `StreamBuilder`/`FutureBuilder` — use Riverpod states.
* No business logic in repositories (fetch/push only).
* No state writes after `await` without an `if (ref.mounted)` guard.
* No hardcoded strings — `context.l10n`. No hardcoded colors — `colorScheme`.
* No obese widgets (>300 lines) — extract private `_SubWidget`s.
* No `dynamic`. No codegen for models (manual `copyWith`/`toJson`/`fromFirestore`).

## Domain Rules

* **Isolation**: every query filtered by `uid`.
* **Immutability**: every model has `copyWith`.
* **Validation**: validate at UI before calling Notifier methods.

## Quality Assurance

* **Testing**: Every new feature or modification must include associated tests (Unit, Widget, or
  Integration).
* **Code Quality**: "If it's not testable, the architecture is likely wrong."
