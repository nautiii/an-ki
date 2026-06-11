# Architecture Rules

## Layers
1. **UI**: Dumb widgets. No direct Firebase access. Use `context.l10n`.
2. **Provider (Riverpod)**: Manages state and logic. Bridge between UI and Repositories.
3. **Repository**: Data abstraction. Handles Firestore/Storage calls. No `BuildContext`.
4. **Service**: Wrappers for external plugins (Notifications, Biometrics). Can be singletons.

## Principles
* **Firestore**: Use `factory Model.fromFirestore` for mapping. Queries use `uid` for isolation.
* **Real-time**: Prefer Streams (`.snapshots()`) in Providers for auto-updating UI.
* **L10n**: 100% translatable. Use `context.l10n`. No hardcoded strings.
* **Logic Location**: Repos handle data; Providers handle business/UI logic; UI renders state.
* **Enums**: Intelligent enums with extensions for UI properties (labels, icons).
* **Extensions**: Extensively used for formatting (`DateTime`) and UI mapping.
