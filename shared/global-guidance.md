# Global Anti-Patterns & Domain Rules

## Anti-Patterns (Avoid)
* **Logic in Build**: No controller instantiation or future launching in `build()`.
* **Direct Firebase in UI**: All data must flow through Providers.
* **Obese Widgets**: Max 200-300 lines; extract sub-components.
* **setState for Shared State**: Use Riverpod for cross-screen data.
* **Hardcoded Strings**: Use `context.l10n`.
* **Nested Builders**: Avoid `StreamBuilder/FutureBuilder` nesting; use Riverpod states.
* **Logic in Repository**: Keep repositories focused on data Fetch/Push. Logic belongs in Providers.

## Domain Rules
* **User Isolation**: All data queries must be filtered by `uid`.
* **Immutability**: Every model must have a `copyWith` method.
* **Validation**: Perform UI-level validation before calling Notifier methods.

## Quality Assurance
* **Testing**: Every new feature or modification must include associated tests (Unit, Widget, or Integration).
* **Code Quality**: "If it's not testable, the architecture is likely wrong."
