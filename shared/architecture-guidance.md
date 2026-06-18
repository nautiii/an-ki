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
├── core/                 # cross-feature infrastructure
│   ├── common/           # shared widgets (anki_text_field, header, bottom_bar…)
│   ├── extensions/       # DateTime/String/l10n formatting & UI mapping
│   ├── providers/        # app-wide state (navigation, locale)
│   ├── services/         # singletons (notification_service, biometric_service)
│   └── theme/
└── features/<feature>/
    ├── data/
    │   ├── models/       # XModel + input models (CreateXInput)
    │   └── repositories/ # XRepository + xRepositoryProvider
    ├── providers/        # XNotifier + XState + derived providers
    └── widgets/ | screens/
```

* New code goes in the matching layer of its feature. Shared/reused code → `lib/core/`.
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
