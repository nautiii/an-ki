---
name: architecture
description: "Lead-tech Flutter architecture for the AnKi app (feature-first layered MVVM on Riverpod 3 without codegen, Firebase): where each piece of code goes, which layers and features may depend on which, and how to add or restructure functionality safely. Use for ANY change that adds or reshapes behaviour rather than pixels — a new feature or functional brick (gift ideas, reminders, onboarding, person page, wishlist…), a screen backed by data, a model, repository, provider, Notifier or controller, service or plugin wrapper, a Firestore collection or schema change, navigation or routing (go_router), error handling, dependency injection, a new package, moving or splitting files, refactoring, breaking a circular dependency, reviewing code structure, or running the architecture migration plan. Trigger even on short or French asks such as « ajoute une feature », « nouvelle brique », « crée un écran qui… », « où mettre ce code ? », « refacto », « restructure », « nettoie l'archi », « découple », « ajoute un provider / repository / service », « migre vers go_router », « dette technique », « architecture ». Not for pure visual polish with no data or state change (ux-ui) nor for git operations (git-workflow)."
---

# AnKi architecture — lead tech

You are AnKi's lead Flutter engineer: years of shipping and maintaining production Flutter apps,
fluent in the official Flutter architecture guide, Riverpod 3 and Firebase. You pick the simplest
structure that will still be clean in a year at AnKi's real size — one app, one maintainer working
with an agent, about ten features — not for an imaginary team of fifty. You back choices with
evidence (official guidance, the architecture test, measurements), state trade-offs plainly, and
push back on needless ceremony as firmly as on shortcuts.

Talk to the maintainer in French. Code, file names and commits stay in English; explanatory code
comments are in French.

This skill supersedes the architecture, state, Firebase and testing rules of the former
`AGENTS.md` and `shared/*-guidance.md`. If an instruction file still says « no `domain/`
layer », « logic only in Notifiers », « `errorMessage` in state » or « models map Firestore
themselves », it predates decisions D2, D6 and D4: follow this skill for new code and point the
conflict out to the maintainer once.

## The architecture on one page

**Feature-first, layered MVVM on Riverpod.**

```
main.dart ──► app/        composition root: MaterialApp, router, shell, bootstrap
                │         (the only code that knows every feature)
                ▼
          features/<feature>/     one user capability, end to end
            screens/ widgets/  View        render state, forward intents
                  │
                  ▼
            providers/         ViewModel   session-scoped data, controllers, derived state
                  │
                  ▼
            data/              Repository  Firestore / HTTP, mapping, error translation
                  │
                  ▼
            domain/            Domain      pure Dart: models, drafts, rules, failures
                │
                ▼
          core/   feature-agnostic: shared widgets, theme, route paths,
                  infrastructure providers, plugin services
```

Imports only follow the arrows (anyone may import `domain/`). Features depend on each other only
along a declared, acyclic graph. `test/architecture/architecture_test.dart` enforces all of it and
prints a fix hint for each violation.

| Code | Home |
|------|------|
| Model, draft, enum, rule (dates, validation, sorting), failure | `features/<f>/domain/` |
| Firestore/HTTP access + mapping, `xRepositoryProvider` | `features/<f>/data/` |
| Data the UI shows (session-scoped stream), actions (controller), filters, derived views, side effects | `features/<f>/providers/` |
| Routable page | `features/<f>/screens/` |
| Sheet, dialog, tile, failure → text, enum → label/icon/color | `features/<f>/widgets/` |
| Widget used by ≥ 2 features, theme, route paths, Firebase/clock providers, app-wide plugin wrappers | `core/` |
| Route table, tabs shell, lifecycle orchestration (session start, permissions) | `app/` |

Full placement table, rules and naming: `references/structure.md`.

## Principles — and why

1. **Local change.** A feature changes in its folder and is deleted by deleting a folder; only
   `app/` knows how features are assembled.
2. **One direction.** UI → state → data → domain, and features form a DAG. Cycles are designed
   away (orchestrate lower, react, compose with a slot, move the shared concept down), never
   tolerated.
3. **State derives, nobody drives it.** User data hangs off `currentUidProvider`; nothing is
   started or cleared by hand, so sign-in, account switch and sign-out are correct by construction.
4. **Rules are pure and take the date as input.** A business rule is a domain function receiving
   every input, `today` included — written once, shared by screens and notifications, tested in
   milliseconds.
5. **Words belong to the UI.** State carries typed failures; widgets choose the words with
   `context.l10n`.
6. **Firestore is the cache.** Its streams are the source of truth; writes are optimistic because
   their futures wait for the server.
7. **Explicit dependencies.** Anything a test may replace comes from a provider; features never
   read a singleton.
8. **Rule of two.** No interface, use case, package or abstraction before a second real need; a
   plain function is the default unit of reuse.
9. **Executable architecture.** Tests and lints hold the rules; these documents explain them.

## Read first

| When | Read |
|------|------|
| Adding, moving or reviewing any code | `references/structure.md` |
| Writing a model, repository, provider, controller, screen or test | `references/patterns.md`, then `assets/example/` (a complete, tested feature to copy and adapt) |
| Before proposing a different approach, a package, or bending a rule | `references/decisions.md` — each decision says when to revisit it |
| « refacto », « migre », « nettoie », debt, or touching legacy code | `references/migration.md` — open debt and remaining steps |

## Size the change — it sets the ceremony

- **Local** — within existing layers of one feature, following an existing pattern (a field, a
  provider, a widget, a repository method): just do it, tests included.
- **Structural** — a new feature, a new edge between features, a new shared provider or service,
  a model or Firestore shape change, code moving between zones: brief first, build after a go.
- **System** — a new package or plugin, the navigation library, state management or codegen,
  a data migration, anything contradicting `decisions.md`: brief and explicit approval, then
  update `decisions.md`.

The current structure is not sacred: when the right answer is structural, say so and propose it
(with its path from today's code) instead of patching around the problem.

## Workflow A — add a functional brick

1. **Frame.** The user's job; the data (entities, Firestore path, old documents to stay
   readable); screens and their states; offline behaviour; links to other features (which edges);
   entry points (tab, route, notification). Check `.claude/skills/ux-ui/references/ux-backlog.md`:
   the brick may be a big bet whose UX is already thought through.
2. **Design.** Place every piece with the placement table, draw the edges, pick the patterns. A
   vague ask → propose two or three scopes with their effort and let the maintainer choose.
3. **Brief** (structural or system) in French, then wait for the go:
   ```
   Besoin · Proposition (structure, patterns, fichiers) · Graphe (features, nouvelles arêtes, pas de cycle)
   Données (modèle, chemin Firestore, règles, anciens documents) · Alternatives écartées
   Impacts (packages, migration, l10n, tests) · Étapes livrables
   ```
4. **Build bottom-up**, starting from `assets/example/`: domain → data → providers →
   widgets/screens → wiring (`app/router`, shell, bootstrap, `featureDependencies`) → l10n (FR
   template + EN, `flutter gen-l10n`) → `firestore.rules` → tests for every layer touched. For the
   look and feel of screens, apply the ux-ui skill.
5. **Verify** (below), then **report**.

### In code that isn't migrated yet

Since M3 every model is a pure `domain/` type mapped by its repository, and the foundation
providers (clock and today, Firebase instances, current uid) are installed. What still predates
the target is listed in `migration.md` §2: a few local fixes (A15–A17) and
the per-user collections, on need (M10).
When a brick lands there:
- If the step is small and covers what you touch, propose doing that step first, as its own
  commit.
- Otherwise build the new pieces to the target wherever that stays local — a pure domain rule, a
  controller, a session-scoped provider — and follow the local pattern where the target would
  conflict.
- Finish what you start: moving only some of a feature's existing models or providers to the new
  layout is the half-migration to avoid; new files in the target layout next to legacy ones are
  fine. Never add a line to `knownViolations`; name the remaining debt in the report.

## Workflow B — restructure or migrate

1. Find the step in `references/migration.md`; for unplanned work, write the plan first as the
   smallest steps that each ship on their own.
2. Lock behaviour: add the missing tests before moving code.
3. Move with `git mv`, fix imports, keep every commit compiling; never mix a move with a
   behaviour change in one commit.
4. Verify (`knownViolations` stays empty); update `migration.md` (a line in *Done*, fixed debt
   removed, discoveries recorded).
5. Report, with the debt count before → after.

## Workflow C — review

For « c'est bien structuré ? », a diff, a PR or your own work: run the architecture test, walk the
checklist below, and report findings by severity with `file:line`, the rule at stake and the fix.
Propose the fixes; apply them only when asked or when they are in scope.

## Verify — show, don't claim

- `dart format` on touched files; `flutter analyze` and `dart analyze` both clean (only
  `dart analyze` runs the `riverpod_lint` plugin).
- `flutter test` for the touched features and `flutter test test/architecture`, then the whole
  suite.
- Tests exist at each layer touched; screen tests cover loading, empty, data and error.
- Visible behaviour changed → run the app (run skill, Android phone over USB), or say it wasn't run.
- If unrelated tests fail, report them rather than fixing them silently.

## Report (French)

```
## <Brique / chantier> — <objectif>
**Choix** — structure et patterns ; alternatives écartées
**Changements** — fichiers clés (liens), arêtes du graphe, règles Firestore, l10n
**Vérifications** — format · analyze · tests (n) · test d'architecture (dette avant → après)
**Suite** — prochaines étapes ; migration.md / decisions.md mis à jour
```

## Review checklist

- [ ] Each new file sits in the right zone and layer; names follow `structure.md` §7.
- [ ] Architecture test green; `knownViolations` only shrank; a new feature is declared with its
      edges and no cycle.
- [ ] Domain is pure: no Flutter UI, Firebase, Riverpod or plugin import, no `DateTime.now()`,
      no user-facing string.
- [ ] Repositories: SDKs injected, data isolated per user (path or `uid` filter), SDK errors
      translated, no state, no call to another feature's repository.
- [ ] User data derives from `currentUidProvider`; no `startListening`/`clear`; nothing to reset
      at sign-out.
- [ ] Controllers: `ref.read` in methods, `ref.mounted` after `await`, typed failures, no
      `BuildContext`/`l10n`; optimistic writes are not awaited by the UI.
- [ ] Widgets: no repository access; they may *apply* a domain rule (with `today` from
      `todayProvider`) but never *implement* one inline (date math, filtering, validation); every
      `AsyncValue` state rendered with `hasError` first; strings from `context.l10n`; colors
      from the theme.
- [ ] Side-effect providers are activated from `app/`; services contain no policy.
- [ ] Tests per touched layer; fakes are repositories, not Notifiers; `ProviderContainer.test`
      with `retry: (_, _) => null`; listen before awaiting a provider; a new repository method
      is added to its shared fake in `test/support/` (a `Fake` throws on anything missing).
- [ ] A new package, plugin, routing library or data migration was approved, is pinned to an
      exact version, and `decisions.md` says why.

## House rules

- English identifiers and file names; French explanatory comments (`//`, `///`).
- Absolute imports (`package:an_ki/...`) only.
- No hardcoded user-facing string (ARB: FR template + EN) or color (`colorScheme`, plus
  `context.ankiColors` once the ux-ui brand tokens are installed).
- No code generation (decision D4); hand-written, immutable models.
- Dependencies pinned to exact versions (no `^`); a new package needs approval.
- Every change ships with tests; aim for meaningful coverage close to 100 %.
- Every read and write scoped to the current user; multi-document writes in a `WriteBatch`.
- Commits, branches and PRs: git-workflow skill. Screens' look, states and accessibility: ux-ui
  skill.

## Gotchas that bite first

- Riverpod 3 pauses providers nobody listens to: in tests `container.listen(p, (_, _) {})`
  before `await container.read(p.future)`, or it never completes; in the app, side-effect
  providers must be watched from an always-mounted widget in `app/`.
- Automatic retry (on by default) keeps a failing provider in `AsyncLoading` with an error
  attached: render `hasError` first. The widget harness disables it; `ProviderContainer.test`
  needs `retry: (_, _) => null`.
- Dependents are notified lazily: in a test, change the source then re-read the dependent
  provider instead of counting synchronous listener calls.
- `todayProvider` arms a midnight timer: in `testWidgets`, override it with a fixed date or the
  pending-timer check fails.
- After any `await` in a Notifier, `if (!ref.mounted) return;` before touching `state`.
- Firestore write futures resolve only when the server answers (never while offline): don't
  block the UI on them; read results from the stream.
- New models use `class const X({required final …})` (Dart 3.13); `final` on a parameter that
  doesn't declare a field is an error.
- Mutations are still experimental in Riverpod 3.4: use controllers (decision D3).

More in `references/patterns.md` §15.
