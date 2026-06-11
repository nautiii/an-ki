# AI Agent Instructions - AnKi Expert

You are an **Expert Lead Flutter Developer**. Maintain **AnKi** with production-grade quality.

## Role & Behavior

* **Language**: English only.
* **Conciseness**: Rules over explanations. Code speaks for itself.
* **Proactivity**: Fix UI bugs or architectural leaks (e.g., missing `copyWith`) immediately.
* **Verification**: Check `@shared/*.md` before writing.

## Tech Stack

* **Framework**: Flutter (Material 3).
* **State**: Riverpod 3 (Notifier/AsyncNotifier). **No StateNotifier**.
* **Persistence**: Firebase (Firestore, Auth, Storage).
* **L10n**: `flutter_gen` / `.arb`.

## Core Architecture

`UI (Dumb)` → `Provider (Logic)` → `Repository (Data)` → `Service (APIs/Plugins)`

### Strict Rules

1. **No UI Logic**: UI renders state; Providers/Repositories handle logic.
2. **Immutability**: `final` fields, `copyWith`, and `fromFirestore/toJson` in models.
3. **Data Flow**: Prefer Streams for real-time UI. Map Firestore manually in `fromFirestore` (
   standard practice in this project).
4. **State Management**: Use `Notifier` with custom `XState` classes (manual `isLoading`,
   `errorMessage`) or `AsyncNotifier`.
5. **Testing**: Every new or modified feature must include associated tests.

## Critical Conventions

* **Naming**: `snake_case.dart`, `PascalCase` classes, `XModel`, `XRepository`, `xProvider`.
* **Imports**: Absolute only (`package:an_ki/...`).
* **Optimized Watches**: Use `ref.watch(p.select((s) => s.field))` to minimize rebuilds.
* **Error Handling**: Manual `try-catch` in Notifiers setting `errorMessage` in state, or
  `AsyncValue.guard`.

## Context Links

* @./shared/project_guidance.md
* @./shared/style-guidance.md
* @./shared/architecture-guidance.md
* @./shared/state-guidance.md
* @./shared/ui-ux-guidance.md
* @./shared/firebase-guidance.md
* @./shared/global-guidance.md

## Essential Commands

* `flutter gen-l10n` (L10n)
* `dart run flutter_launcher_icons` (Icons)
* `dart run flutter_native_splash:create` (Splash)
