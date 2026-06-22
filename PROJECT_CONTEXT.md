# Project Context — AnKi (Kairos)

> Long-term project memory: product intent, rationale, and roadmap.
> Operational rules for code generation live in `AGENTS.md` and `shared/*.md`.

## Product Vision

AnKi is a production-ready birthday management app — modern, minimalist, reliable.
It solves the "forgotten birthday" problem: centralize contacts' birthdays with intelligent,
local-first notifications and a frictionless, pixel-perfect experience.

## Application Overview

Birthdays are stored locally and synced across devices via Firebase. Notifications are scheduled
on-device (local-first) so reminders fire reliably regardless of connectivity, while Firestore keeps
data consistent across a user's devices.

## Current Features

* **Authentication**: Google, Email/Password, Anonymous — with biometric lock.
* **Birthday management**: full CRUD, categories, search, proximity-based sorting, calendar view.
* **Smart notifications**: timezone-aware, scheduled via `flutter_local_notifications` (day-of + J-7).
* **Contact integration**: import birthdays from phone contacts.
* **Book scanning**: ISBN scanner (`mobile_scanner`) + Google Books API for gift ideas.

## Planned Features / Roadmap

> Confirm with the maintainer before assuming scope; this section captures direction.

* Expand the book scanner into a broader gift-ideas / wishlist module.
* Richer category management and filtering.
* Additional reminder cadences and per-contact notification preferences.
* Deeper cross-device sync and sharing scenarios.

## User Experience Principles

* **Pixel perfect**: strict Material 3 + 8dp grid adherence.
* **Zero empty states**: always show feedback, a placeholder, or a CTA.
* **Fluidity**: native-feel transitions and haptic responses.

## Technical Decisions & Rationale

* **Layered architecture** (UI → Provider → Repository → Service): keeps UI dumb and logic testable;
  swappable data/service layers.
* **Riverpod 3 (Notifier API)**: testability and fine-grained rebuilds via `.select()`.
  `StateNotifier` is deliberately avoided.
* **Firebase (Firestore/Auth/Storage)**: managed backend with offline persistence; small images stored
  as base64 to avoid extra Storage round-trips.
* **Local-first notifications**: reliability independent of network; timezone-aware to avoid drift.
* **Security**: biometric lock (`local_auth`) + secure token storage; all data isolated per `uid`.
* **L10n by `flutter_gen` / `.arb`**: 100% translatable UI, no hardcoded strings.
* **Feature-first structure**: each feature owns its `data/`, `providers/`, and UI; shared infra in `core/`;
  app wiring (router, `MaterialApp`, cross-feature bootstrap) in `lib/app/`. `core/` is feature-agnostic and
  never imports a feature. Logic lives in Notifiers — no separate `domain/` use-case layer, kept intentionally lean.
* **Manual state & mapping (no codegen)**: `XState` + `copyWith` and `fromFirestore`/`toJson` are hand-written
  rather than generated (`freezed`/`json_serializable`). Trade-off: more boilerplate, zero build-runner friction
  and full control over Firestore mapping.
* **Imperative routing**: centralized in `lib/app/router/` (`AppRoutes` names + `AppRouter` table),
  wired by `lib/app/app.dart`; `home` driven by auth state; tab state via a `navigationProvider`.
  No `go_router` — kept simple while the surface is small (revisit if deep links/web grow).

## Domain Model

* **Birthday** — core entity; drives notification scheduling.
* **Category** — user-defined label for grouping birthdays.
* **User** — profile-linked Firestore document; root of `uid` data isolation.

## Long-Term Goals

* Maintain a friction-free, "pixel perfect" experience as features grow.
* Keep the architecture strictly layered and fully testable as new modules (e.g. gifts) are added.
* Preserve local-first reliability and per-user data isolation as sync scenarios expand.
