# Decisions — what AnKi chose, why, and when to revisit

Architecture decision records, from the research of 2026-10-07 (sources at the end). Each one
says what would make it wrong. Before proposing a change to one of them, check its "Revisit
when"; changing one is a **system** change (brief + approval) and updates this file.

## Contents
- D1 Feature-first, layered MVVM on Riverpod
- D2 No use-case layer; a pure domain layer
- D3 Riverpod 3 without code generation; controllers, not Mutations (yet)
- D4 Hand-written immutable models with primary constructors
- D5 Concrete repositories, no abstract interfaces
- D6 Typed failures + AsyncValue, no Result type
- D7 State derives from the session
- D8 Firestore: SDK cache as source of truth, optimistic writes, per-user paths
- D9 Navigation: go_router, pinned to 17.x
- D10 Executable architecture
- D11 Scale-out path: packages only on real signals
- Sources

---

## D1 — Feature-first, layered MVVM on Riverpod

**Decision.** `lib/features/<feature>/{domain,data,providers,screens,widgets}` + `core/` +
`app/` composition root; Flutter's MVVM roles (View, ViewModel, Repository, Service) mapped onto
those folders; dependencies only point down; features form a declared DAG.

**Why.** AnKi is one app, one maintainer working with an AI agent, ~55 files growing to ~10
features (ideas, reminders, onboarding, person page). Feature folders keep every change local
(commit scopes already follow them), give an agent a bounded context, and make deletion or
extraction mechanical. The layers inside give each kind of code one obvious home.

**Rejected.**
- *Official case-study layout* (`ui/<feature>/`, `data/repositories/`, `domain/models/`): the
  Flutter team's default and agent skill. It shares data naturally, but scatters one feature over
  three trees and loses the per-feature boundary the repo already has. We keep its vocabulary and
  rules (repositories as source of truth, unidirectional flow, no logic in widgets).
- *Clean Architecture everywhere* (use cases + repository interfaces + DTOs per feature): ceremony
  without payoff at this size; the Flutter guide calls the domain layer "Conditional" and use
  cases "unnecessary overhead" in most apps.
- *VGV Feature-First Clean Architecture* (packages per feature, 2026): built for features shared
  across apps or teams; its own guidance keeps layered architecture for a single app with a
  handful of features.

**Revisit when** features must be shared with another app, or a second developer owns a feature
(→ D11).

## D2 — No use-case layer; a pure domain layer

**Decision.** `domain/` holds models, drafts, enums, failures and pure rule functions. No use-case
classes, no repository interfaces. Orchestration lives in controllers; cross-feature flows in the
lowest feature that depends on all participants, or in `app/bootstrap`.

**Why.** The previous rule "no domain layer, logic in Notifiers" left rules with no pure home:
the next-birthday computation existed twice (UI extensions and `NotificationService`),
`DateTime.now()` was read in 9 places, and models imported Firestore and Flutter (all fixed by
M3 and M6). A domain folder of plain functions
fixes that without adding indirection — a function is the smallest possible "use case".

**Revisit when** a single flow combines 3+ repositories *and* is triggered from 2+ places (then a
named application function/class in the owning feature's `providers/`), or when the domain
grows complex enough to deserve its own package.

## D3 — Riverpod 3 without code generation; controllers, not Mutations (yet)

**Decision.** Hand-written providers (`Provider`, `StreamProvider`, `NotifierProvider`,
`AsyncNotifierProvider`, `.family`, `.autoDispose`). Data through session-scoped
`StreamProvider`s; writes through per-concern `AsyncNotifier` controllers. No `StateNotifier`,
no `legacy.dart`.

**Why.** Riverpod's docs now say codegen is optional, "only if you already use code generation
for other things"; AnKi doesn't. Without it we lose generic providers, multi-argument families
(use records) and some lints — none needed here. Mutations are the documented answer to "form
submission state" but are still `experimental/` and "may change in a breaking way without a
major version bump"; the controller pattern gives the same separation of action state from data
state on stable APIs.

**Revisit when** Mutations leave `experimental/` (likely Riverpod 4), or the project adopts
build_runner for another reason (then riverpod_generator becomes cheap).

## D4 — Hand-written immutable models with primary constructors

**Decision.** No freezed/json_serializable. Models use Dart 3.13 primary constructors
(`class const X({required final …})`) and hand-written `==`/`hashCode`, plus a `copyWith`
(`clearX` flags) only where code copies the object; Firestore mapping in `data/`.

**Why.** Dart 3.13 removed the field/constructor duplication (Effective Dart now prefers the
concise syntax); what remains (`==`, mapping, the odd `copyWith`) is small for ~10 models,
explicit, and free of build steps. A hand-written `copyWith` that nobody calls is upkeep without
payoff: every new field must be copied too, and `null` can't clear a field without a flag. Models
come from Firestore and from drafts, they are not edited in memory: on 2026-10-11 five of the six
`copyWith` were called by their own tests only, and were removed. The Flutter guide only "recommends" freezed; immutability is what it
strongly recommends, and we have it.

**Revisit when** models pass ~20 or carry deep nesting, `copyWith`/`==` bugs appear in review,
or the project adopts build_runner anyway. Then freezed 4 "mixed mode" (plain classes +
generated `==`/`copyWith`) is the lightest step. Dart's "value semantics" work (no spec yet) would
remove most of the boilerplate — watch the Dart blog.

## D5 — Concrete repositories, no abstract interfaces

**Decision.** `class XRepository` with constructor-injected SDKs, exposed by `xRepositoryProvider`.

**Why.** The Flutter guide strongly recommends abstract repositories to swap implementations per
environment. In Dart every class is an implicit interface (`class FakeXRepository extends Fake
implements XRepository`), and Riverpod overrides swap implementations in tests or per environment
without an extra abstract type per repository. Same benefit, half the files.

**Revisit when** a repository genuinely has two production implementations (local-only mode,
another backend) — then add the abstract class for that repository only.

## D6 — Typed failures + AsyncValue, no Result type

**Decision.** Repositories translate SDK exceptions into feature failures (`enum` or `sealed`,
implementing `Exception`); controllers expose them through `AsyncValue`; widgets map them to
`l10n` with an exhaustive `switch`. Providers never hold strings or take `AppLocalizations`.

**Why.** Under Riverpod a `Result` returned by repositories is unwrapped and rethrown inside
notifiers anyway; `AsyncValue` is already the data-or-error type at the UI boundary. Typed
failures give the explicitness `Result` aims for, and moving words to the UI fixed the former
`AuthNotifier` methods that took `l10n` (M5).

**Revisit when** a pure-Dart flow outside Riverpod needs explicit error values (background
isolate, CLI tool).

## D7 — State derives from the session

**Decision.** `currentUidProvider` is the root of all user data; session-scoped providers
`ref.watch` it. No `startListening`/`clear`, no reset lists at sign-out. App-lifecycle reactions
(profile creation, permission requests) live in `app/bootstrap`.

**Why.** Riverpod's docs: providers should initialize themselves; there is deliberately no
"reset all providers"; providers that depend on the user should watch the user. Today's
imperative start/clear spreads session knowledge into `AppInitializer` and `SettingsScreen` and
can leak the previous account's data when a reset is forgotten.

**Revisit when** offline-only (no account) mode arrives: the session then becomes "local profile
or uid", still one provider at the root.

## D8 — Firestore: SDK cache as source of truth, optimistic writes, per-user paths

**Decision.** Repositories expose `snapshots()` streams; no second cache (no Riverpod offline
persistence). UI flows don't await Firestore writes. New collections live under
`user/{uid}/<collection>`; legacy top-level collections keep `uid` filtering until a planned
migration. Client timestamps from `clockProvider`.

**Why.** Persistence is on by default on Android/iOS; listeners emit local writes immediately
while write futures resolve only on server acknowledgement — awaiting them freezes the UI
offline. Per-user paths make isolation structural and rules trivial; the cost is explicit
deletion of subcollections at account deletion. Ownership is enforced by the security rules, not
by read-before-write checks in repositories (which would duplicate them and delay every write).

**Revisit when** data must be shared between users (top-level collection + membership rules),
or server-side account cleanup (Cloud Function / "Delete User Data" extension) becomes available
— then client-side deletion shrinks.

## D9 — Navigation: go_router, pinned to 17.x

**Decision.** go_router since M7 (2026-10-11), first planned for the first of B3 (notification
actions), B4 (a person page addressed by id) or B5 (onboarding redirects), and brought forward
by the maintainer. Paths stay plain constants in `core/routing/`; the router
lives in `app/router/`.

**Why.** Flutter's docs: small apps without complex deep linking can use Navigator, but named
routes are not recommended once deep links matter; go_router stays the team's recommendation for
most apps and is feature-complete (bug fixes only). Notification taps that must open a screen
with a correct back stack — including from a cold start — are exactly where a Router helps, and
AnKi's roadmap gets there soon.

**How.** go_router 18 depends on the new `material_ui`/`cupertino_ui` packages, so 17.5.0 (the
last 17.x, same API) is pinned until the Material decoupling migration. The `GoRouter` is built
once in `appRouterProvider`; Riverpod 3.4 has no `Listenable` adapter, so a `ValueNotifier` fed
by `ref.listen(authAccessProvider)` is its `refreshListenable`, and the pure `accessRedirect`
decides. The tabs are a `StatefulShellRoute` whose container keeps every branch mounted and
cross-fades the current one (as before, honouring disabled animations); go_router_builder is
out (build_runner).

**Revisit when** the Material decoupling lands (move to go_router 18+).

## D10 — Executable architecture

**Decision.** The rules are tests and lints, not just prose: `test/architecture/` (imports,
layers, feature DAG, debt ratchet), the analyzer with strict modes, `riverpod_lint` through the
analyzer plugin system, and the review checklist for what tools can't see.

**Why.** An architecture that only lives in a document erodes at the first rushed feature — the
current 25 violations prove it. A zero-dependency test gives exact, actionable failures in ~1 s
and lets debt shrink but never grow. Off-the-shelf import linters exist (`import_lint` 2.x,
`import_rules`, DCM's paid `avoid-banned-imports`) but none expresses the feature DAG and the
ratchet as simply; one may be added later for in-IDE feedback.

**Revisit when** the test becomes hard to maintain (packages make most of it a pubspec concern).

## D11 — Scale-out path: packages only on real signals

**Decision.** One package today. Extract feature or layer packages (pub workspace) only when two
apps share code, a team owns a feature, or analysis/build time hurts.

**Why.** Packages add pubspecs, versioning and cross-package refactoring friction. The D1 rules
already give features the shape of packages, so extraction stays a mechanical move when needed.

---

## Sources (checked 2026-10-07)

- Flutter architecture guide, recommendations and case study — docs.flutter.dev/app-architecture
  (+ "session state" section added 2026-05-04, flutter/website #13352).
- Flutter navigation and deep linking — docs.flutter.dev/ui/navigation (2026-09-29).
- Riverpod 3 — riverpod.dev/docs/whats_new, /docs/3.0_migration, /docs/concepts2/{mutations,
  retry,offline,family,refs}, /docs/root/do_dont, /docs/root/faq, /docs/how_to/testing; package
  CHANGELOG 3.0.0 (2025-09-10) → 3.4.3 (2026-09-04).
- riverpod_lint 3.1.9 on `analysis_server_plugin` (verified locally: active with `dart analyze`,
  silent with `flutter analyze`).
- Dart 3.13 primary constructors — dart.dev/language/primary-constructors, Effective Dart usage;
  verified locally (dot shorthands need 3.10, private named parameters 3.12, primary constructors
  3.13).
- Dart data classes status — dart.dev blog "Bringing primary constructors to Dart" (2026-08-20);
  dart-lang/language #314.
- build_runner 2.13–2.16 performance, freezed 4.0 (2026-08-22) — package changelogs.
- go_router 18.0.2 README ("feature-complete") and changelog — pub.dev.
- Code With Andrea: Riverpod architecture, feature-first structure, repository abstraction,
  error handling (2022–2026).
- Very Good Ventures: layered architecture; Feature-First Clean Architecture (2026-08-10).
- Android domain layer guide (2026-03-05) — use cases optional.
- Firebase: offline persistence, listen to realtime updates, structure data, rules basics,
  "rules are not filters" — firebase.google.com (2026-10).
