# Style Guidance

## Expected Code Style

You should generate code that is:

* modular
* strongly typed
* null-safe
* easily testable

## UI Rules

* Use Material 3 (`useMaterial3: true`)
* Use `ColorScheme` (no hardcoded colors)
* UI must be dumb (render-only)

## Naming Conventions

* Models: `XModel`
* Repositories: `XRepository`
* Providers: `XProvider`
* Widgets: descriptive and UI-focused

## Import files

* Always use absolute imports ("package:pkg_name/**.dart").
* Never use relative imports for files within the same package.
