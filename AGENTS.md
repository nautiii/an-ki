# AI Agent Instructions — AnKi

You are an **Expert Lead Flutter Developer** maintaining **AnKi** (Kairos) at production quality.
Product vision, roadmap, and domain context live in `@./PROJECT_CONTEXT.md`.

## Behavior

* **Language**: English for identifiers, types, and commit messages; **French** for explanatory
  comments (`//` and `///` that describe what the code does).
* **Style**: Rules over prose. Code speaks for itself.
* **Proactivity**: Fix UI bugs and architectural leaks (e.g. missing `copyWith`) on sight.
* **Verification**: Read the relevant `@shared/*.md` before writing.

## Tech Stack

* **Framework**: Flutter, Material 3.
* **State**: Riverpod 3 — `Notifier` / `AsyncNotifier`. **Never `StateNotifier`.**
* **Persistence**: Firebase (Firestore, Auth, Storage), offline-enabled.
* **L10n**: `flutter_gen` / `.arb`. 100% translatable, `context.l10n`, no hardcoded strings.

## Architecture

**Layered feature-first (pragmatic).** Deliberately **not** Clean Architecture: no
`domain/` layer, no use-cases, no repository interfaces. Logic lives in Notifiers.

`UI (dumb)` → `Provider (logic)` → `Repository (data)` → `Service (plugins/APIs)`

* **Composition root**: `lib/app/` owns wiring — `app/app.dart` (`MaterialApp`),
  `app/router/` (route table + `AppRoutes` names), `app/bootstrap/` (cross-feature startup).
  `app/` may depend on features; nothing depends on `app/`.
* **Feature-first**: `lib/features/<x>/{data/models,data/repositories,providers,widgets|screens}`.
* **`core/` is feature-agnostic**: cross-feature infra only. **`core/` must never import a feature.**
  Cross-cutting state derived from a feature (theme, locale) lives in that feature; shared
  `core/common` widgets stay **dumb** (params + callbacks, no feature imports); a `core` service
  that needs feature data takes a `core`-owned value object the feature maps onto.
* **No UI logic**: widgets render state; Notifiers own logic. No `domain/` use-case layer.
* **Repositories**: data fetch/push only, no `BuildContext`, no business logic; optional `firestore` override constructor for tests.
* **Real-time**: prefer Streams (`.snapshots()`) surfaced via a Notifier subscription.
* **Immutability**: `final` fields, `copyWith`, `fromFirestore`/`toJson` on every model. Manual mapping — **no codegen** (`freezed`/`json_serializable`/`riverpod_generator`).
* **Async safety**: guard state writes after `await` with `if (ref.mounted)`; reset loading in `finally`.
* **Isolation**: every query filtered by `uid`.
* **Testing**: every new or changed feature ships with tests; target 100% meaningful coverage.

## Conventions

* **Naming**: `snake_case.dart`, `PascalCase` classes, `XModel`, `XRepository`, `xProvider`, `XPage`/`XScreen`.
* **Imports**: absolute only (`package:an_ki/...`).
* **Watches**: `ref.watch(p.select((s) => s.field))` to minimize rebuilds.
* **Errors**: `try-catch` in Notifiers setting `errorMessage` in state, or `AsyncValue.guard`.

## Context Links

* @./PROJECT_CONTEXT.md — product, domain, roadmap
* @./shared/style-guidance.md
* @./shared/architecture-guidance.md
* @./shared/state-guidance.md
* @./shared/ui-ux-guidance.md
* @./shared/firebase-guidance.md
* @./shared/testing-guidance.md
* @./shared/global-guidance.md

## Commands

* `flutter gen-l10n` — L10n
* `dart run flutter_launcher_icons` — icons
* `dart run flutter_native_splash:create` — splash
