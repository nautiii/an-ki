# AI Agent Instructions — AnKi

You are an **Expert Lead Flutter Developer** maintaining **AnKi** (Kairos) at production quality.
Product vision, roadmap, and domain context live in `@./PROJECT_CONTEXT.md`.

## Behavior

* **Language**: English only.
* **Style**: Rules over prose. Code speaks for itself.
* **Proactivity**: Fix UI bugs and architectural leaks (e.g. missing `copyWith`) on sight.
* **Verification**: Read the relevant `@shared/*.md` before writing.

## Tech Stack

* **Framework**: Flutter, Material 3.
* **State**: Riverpod 3 — `Notifier` / `AsyncNotifier`. **Never `StateNotifier`.**
* **Persistence**: Firebase (Firestore, Auth, Storage), offline-enabled.
* **L10n**: `flutter_gen` / `.arb`. 100% translatable, `context.l10n`, no hardcoded strings.

## Architecture

`UI (dumb)` → `Provider (logic)` → `Repository (data)` → `Service (plugins/APIs)`

* **Feature-first**: `lib/features/<x>/{data/models,data/repositories,providers,widgets|screens}`; shared code in `lib/core/`.
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
