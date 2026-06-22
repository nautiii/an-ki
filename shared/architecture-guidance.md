# Architecture Rules

`UI (dumb)` → `Provider (logic)` → `Repository (data)` → `Service (plugins/APIs)`

## Layers

* **UI**: dumb widgets, no direct Firebase, `context.l10n`, renders state only.
* **Provider/Notifier**: bridge UI↔Repository; owns all business & UI logic, orchestration, error mapping.
* **Repository**: data fetch/push only. No `BuildContext`, no business logic, no UI strings. Exceptions bubble up.
* **Service**: wrappers for external plugins (notifications, biometrics, secure storage); may be singletons.

> Logic lives in Notifiers, **not** in separate use-case classes — this project has no `domain/` layer. Keep it that way.

## Project Structure (feature-first)

```
lib/
├── app/                  # composition root (may depend on features)
│   ├── app.dart          # MaterialApp: theme, locale, l10n, route table
│   ├── router/           # AppRoutes (names) + AppRouter (route table)
│   └── bootstrap/        # AppInitializer: cross-feature startup orchestration
├── core/                 # cross-feature infrastructure — NEVER imports a feature
│   ├── common/           # dumb shared widgets (anki_text_field, header, bottom_bar…)
│   ├── extensions/       # DateTime/String/l10n formatting & UI mapping
│   ├── providers/        # app-wide, feature-agnostic state (navigation)
│   ├── services/         # singletons (notification_service, biometric_service)
│   └── theme/            # AppTheme data (themeProvider lives in the user feature)
└── features/<feature>/
    ├── data/
    │   ├── models/       # XModel + input models (CreateXInput)
    │   └── repositories/ # XRepository + xRepositoryProvider
    ├── extensions/       # feature-specific extensions (e.g. birthday)
    ├── providers/        # XNotifier + XState + derived providers
    └── widgets/ | screens/
```

* New code goes in the matching layer of its feature. Shared/reused code → `lib/core/`.
* **`core/` must never import `features/`.** Cross-cutting state whose source of truth is a
  feature (theme, locale from the user doc) lives in that feature. A `core/common` widget that
  would need feature data must be **dumb** (take params + callbacks). A `core` service that needs
  feature data takes a `core`-owned value object (e.g. `BirthdayReminder`) the feature maps onto.
* App wiring (routing, startup) lives in `lib/app/`, not in `core/`.
* **One provider file per concern**; expose the `xRepositoryProvider` at the feature level next to the repository.

## Models

* Manual mapping only — **no `freezed` / `json_serializable` / codegen**. Every model: `final` fields,
  `const` constructor, `copyWith`, `factory X.fromFirestore`, `toJson`.
* `fromFirestore` casts and null-guards explicitly; convert `Timestamp`↔`DateTime` inline.
* `toJson` omits null optionals (`if (picture != null) 'picture': picture`).
* **Input models** (`CreateXInput`): carry raw form data (incl. `File?` for images) separately from the
  persisted `XModel`. Repositories turn input → persisted data.

## Dependency Injection

* Repositories are provided via `Provider` (`final xRepositoryProvider = Provider((ref) => XRepository());`).
* Notifiers access dependencies through `ref` — never instantiate repositories/services directly.
* Repositories take an **optional override constructor** (`XRepository({FirebaseFirestore? firestore})`)
  so tests inject `fake_cloud_firestore`.

## Data Flow

* **Real-time**: prefer Streams (`.snapshots()`) surfaced through a Notifier subscription.
* **Derived state**: compute filtered/sorted/aggregated views in `Provider`s that `ref.watch` the base
  state — never duplicate that logic in widgets.
* **Enums**: intelligent enums with extensions for UI props (labels, icons).
