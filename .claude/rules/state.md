---
paths:
  - "lib/features/*/providers/**"
  - "lib/core/providers/**"
  - "lib/app/bootstrap/**"
---

# State code — providers, notifiers, bootstrap

Riverpod 3.4 with hand-written providers. Patterns with code: architecture skill,
`references/patterns.md` §6–10 and §15; complete reference feature in `assets/example/`.

## Always

- Never `StateNotifier`, `StateProvider` or anything from `legacy.dart`; no `riverpod_generator`.
- `ref.watch` only in `build`; methods use `ref.read`. A getter calling `ref.watch` from a method
  is a bug.
- After every `await`: `if (!ref.mounted) return;` before touching `state`.
- No `BuildContext`, `AppLocalizations`, widget, theme or `core/common` import: state carries
  typed failures, the UI chooses the words.
- Dependencies come from providers (`ref.read(xRepositoryProvider)`); never construct a
  repository or read a `.instance` singleton in new code.
- Business rules are pure domain functions taking every input, today's date included (from
  `clockProvider`/`todayProvider` once installed); providers only wire them.
- `==`/`hashCode` on every state class: Riverpod 3 filters updates with `==`.

## Target shapes for new code

- Data the UI shows: a session-scoped `StreamProvider` watching `currentUidProvider`, so sign-in,
  account switch and sign-out are correct by construction. No `startListening(uid)`/`clear()`.
- Actions: one controller per family of actions (`AsyncNotifier<void>`, named by role:
  `IdeaEditor`), publishing progress and failure as `AsyncValue`. Optimistic Firestore writes
  aren't awaited by the UI (they resolve on server acknowledgement, never offline); awaited
  operations (sign-in, ISBN lookup) start with `if (state.isLoading) return;`.
- UI state (search text, filters, view mode): a small `Notifier<T>` whose `build` watches the
  session, so it resets at sign-out.
- Derived views: a `Provider` calling a domain function; `autoDispose` + `family` per screen or
  id; several family arguments → a record.
- Side effects on data changes (rescheduling notifications): a provider activated from `app/`
  by `ref.watch` in an always-mounted widget — Riverpod 3 pauses providers nobody listens to.
- Lifecycle reactions (profile creation, permission requests) belong to `app/bootstrap`, never
  to a screen.

## Legacy, until migrated

`AuthNotifier` (`AuthState` flags, `l10n` parameters) and `CategoryNotifier` (awaited writes in a
`Notifier<void>`) are the last legacy notifiers. In a bug fix, keep their local pattern; don't
extend it to new code; they migrate in M5 (`migration.md`). Every other piece of state already
follows the target shapes above — copy those, e.g. `BirthdayEditor`, `ContactImport`,
`userProfileProvider`.
