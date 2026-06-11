# Style & Conventions

## Code Style
* **Modularity**: Extract sub-widgets into private `_MySubWidget` classes.
* **Typing**: Strong typing everywhere. No `dynamic`.
* **Const**: Use `const` constructors wherever possible.
* **Imports**: Absolute only. Order: 1. Flutter/Dart, 2. Packages, 3. Internal.

## Naming
* **Files**: `snake_case.dart`
* **Classes**: `PascalCase`
* **Models**: `XModel`
* **Repositories**: `XRepository`
* **Providers**: `xProvider` (camelCase instance)
* **Screens**: `XScreen` / `XPage`

## Immutability
* All model fields must be `final`.
* Implement `copyWith` and JSON mapping in models.
* Avoid logic in constructors.
