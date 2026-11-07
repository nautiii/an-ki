---
name: dead-code
description: "Sweep AnKi for dead code precisely: a throwaway Dart package on analyzer 14.5.0 resolves lib/ and test/ in one context and lists what lib/ declares but nobody references, what only tests use, optional parameters lib/ never passes and dead ARB keys. Every finding is checked by hand and shown in French with file:line and a recommendation; only what the maintainer approves is removed, through the commit gate (checks and reviewer), one commit per intent. `check` only reports."
disable-model-invocation: true
argument-hint: "[check]"
model: opus
effort: high
---

# Sweeping AnKi's dead code

Grep can't do this: extensions are used through their members, member names repeat across
classes, dot shorthands (`.standard`; AnKi uses none on 2026-11-07) never name their type, and the analyzer's own
`unused_element` only sees private declarations. The finder resolves lib/ and test/ the way the
compiler does and compares what lib/ declares with what lib/ and test/ reference. Its output is
a list of candidates, not a verdict: the review in step 2 is the real work.

The maintainer typed the command: that is a go for running the finder and reporting. Removing
waits for their approval, finding by finding or group by group. `model: opus` and `effort: high`
apply to the turn that starts the skill; the removals after the maintainer's go run with the
session's model.

**Requested:** `$ARGUMENTS` — `check` stops after the report (step 2); empty means report, then
remove what the maintainer approves.

## 1. Run the finder

From the repository (or worktree) root, after `git status --short` and `git log --oneline -3`:

```bash
rm -rf build/dead_code && mkdir -p build/dead_code
cp -r .claude/skills/dead-code/scripts/. build/dead_code/
(cd build/dead_code && dart pub get --offline && dart run bin/find_dead_code.dart ../..)
```

Read-only for the app, about 1 to 1.5 min. The finder is a package of its own: the app's
`pubspec.yaml` never sees analyzer, and `build/` is gitignored and excluded from analysis
(`flutter clean` wipes the copy, harmless). It needs the app's `.dart_tool/package_config.json`:
run `flutter pub get` first in a fresh worktree, in the Terminal panel (deps-upgrade skill).

- **Check the header** before reading further: `1 contexte(s)` (more means lib/ and test/ were
  resolved apart and every « tests seuls » turns into « inutilisé »: stop and fix the finder), a
  non-zero `clés ARB` count (zero means `l10n.yaml` wasn't read), no `non résolu` line on stderr.
- **Offline resolution fails** (analyzer 14.5.0 left the pub cache): `dart pub get` with the
  network, inside `build/dead_code/` only.
- **After a Dart SDK upgrade**, the finder prints no analysis diagnostic (a `non résolu` line only
  means a file wasn't resolved at all): compare the project's language version with the
  analyzer's (deps-upgrade skill). If analyzer 14.5.0 doesn't know it, bump the pin in
  `scripts/pubspec.yaml` to a release that does, adapt the finder to its API, and commit that
  alone.

## How the finder decides

Knowing its rules is what makes the review fast.

- **Declarations** — every top-level declaration and member in lib/: classes, mixins, enums and
  their values, extensions, typedefs, functions, variables (providers included), fields, getters,
  setters, methods, constructors; plus the optional parameters of functions, methods and
  constructors. In the files gen-l10n writes, only the abstract members of `AppLocalizations`
  count: they are the ARB keys, reported at their line in the template ARB (`intl_fr.arb`).
- **References** — any resolved use from lib/ or test/: call, tear-off, type annotation,
  constructor, annotation, operator, pattern field, dot shorthand. A use of a member also uses
  its class or extension; `values` uses every value of the enum; an enum value uses the
  constructor it invokes (`monthBefore(30)`), counted from that value; a call through an
  override uses the member it overrides, so an interface method stays alive when callers hold
  the implementation. A declaration's references to itself don't count.
- **Ricochet** — a reference from dead code doesn't count, a reference from lib/ code that only
  tests use counts as a test use: `[ricochet]` marks what fell through that chain (the source
  shows « via X »). Two dead declarations that only reference each other stay invisible.
- **Never listed** — `@override` members (judged through the member they override), `main`,
  `@pragma('vm:entry-point')`, `key` parameters, members of a class already listed, and the
  private parameterless constructor of an abstract class (`const AppSpacing._();`, the
  constants-class idiom; a closing line names those classes).
- **Blind spots** — what Dart code never references but something else needs: model fields read
  or written by Firestore (stored data, not dead), assets declared in `pubspec.yaml`, anything a
  platform or plugin calls by name. A tear-off counts as passing every optional parameter; the
  real blind spot is Dart outside `lib/` and `test/`.

## 2. Review, then report

The output has four sections. For each finding, open `file:line` and grep the name in `lib/`,
`test/`, the docs and the skills (`AGENTS.md`, `.claude/rules/`, `.claude/skills/`): a doc that
cites it changes with it. Then recommend:

| Section | Default | Keep or ask when |
|---|---|---|
| Inutilisé dans lib/ et test/ | remove | one step of a deliberate scale (spacing, radii, motion tokens): removing it breaks the vocabulary, ask; a field Firestore stores; something the backlog (`ux-backlog.md`, `migration.md`) plans to use soon |
| Utilisé seulement par les tests | remove it from lib/ and move the tests onto the real API | `@visibleForTesting` constructors of plugin wrappers stay (platform rule); a test-only `copyWith` goes (house rule: only where code copies); a domain constructor tests use as a fixture, or something only `test/architecture/` reads: decide with the maintainer |
| Paramètres optionnels jamais passés par lib/ | remove the parameter, keep its default behaviour | it completes a widget's public API the next screen will need; « passé par les tests seuls » means a test checks a configuration the app never uses: remove both |
| Clés ARB mortes | remove the key from `intl_fr.arb` and `intl_en.arb` (with its `@key` block), then `flutter gen-l10n` (`.claude/rules/l10n.md`) | the string belongs to a feature in progress |

Rules while reviewing:
- An optional parameter marked `@visibleForTesting` and passed only by tests is an injection
  point: keep it (`.claude/rules/platform.md`, `registerBackgroundReplan`).
- A use in `.claude/skills/*/scripts` or `assets/example` is real (e.g. `BirthDate.fromDate` in
  `ui_snapshot_test.dart`): keep or adapt, then rerun that tool.
- After a removal, look for orphaned fakes in `test/support/` (a3b0a53 removed
  `RecordingUserRepository.removedCategories` by hand).
- Code unreachable because of the data but referenced (a3b0a53, `GroupKind.shared`) is out
  of the finder's reach: look for it in the architecture skill's `references/migration.md`.
- Probes go in a worktree, with the finder run on its root: an untracked file under `lib/` or
  `test/` makes `verify-index.sh` fail for every session.

Report in French, grouped by section, one line per finding: `chemin:ligne` — the element — the
recommendation (« supprimer », « garder », « à décider ») and why, in a few words. Then ask which
lines to remove. `check` stops here.

## 3. Remove what was approved

- **Shared tree.** `git status --short` again: if a file to edit holds someone else's uncommitted
  work, stop and ask.
- **Only the removal.** The declaration, its doc comment, imports left unused, the tests that only
  tested it (or rewrite them on the real API), ARB keys in both files then `flutter gen-l10n`
  (`.claude/rules/l10n.md`), and the docs that cite it. No refactoring on the way (`AGENTS.md`).
- **Knock-on effects.** A removal can orphan private helpers (`flutter analyze` reports
  `unused_element`) or new public ones: rerun the finder until the approved sections hold
  nothing new, and bring new findings back to the maintainer before removing them.
- **Green before each commit:** `bash .claude/hooks/verify-index.sh` (format, project norms,
  l10n, `dart analyze --fatal-infos`, tests).
- **One commit per intent**, git-workflow skill: `REFACTOR(<scope>): remove unused <what>` for
  code, `CHORE(l10n): remove unused strings` for ARB keys, the scope from the path. Commit
  through the git-workflow skill, step 4 (stage in one call, commit the index in the next, after
  the checks and the reviewer; the gate refuses paths after `git commit`).

## 4. Report

In French: what was removed and in which commit, what was kept and why, and what ran
(AGENTS.md: show what ran).

## Maintaining the finder

The source lives in `scripts/` (`pubspec.yaml`, `bin/find_dead_code.dart`); edit it there, never
in `build/dead_code/`. `.claude/` is a hidden folder, so the app's analyzers skip it: check the
finder with `dart analyze .` inside `build/dead_code/`. Analyzer 14 traps it already avoids:

- **One context.** One `AnalysisContextCollection(includedPaths: [root])`, files filtered to lib/
  and test/: two included paths make two contexts whose `Element`s differ.
- **No `isSynthetic`.** An implicit getter or setter (`isOriginDeclaration` false) maps to its
  `variable`; a primary-constructor field is `isOriginDeclaringFormalParameter`.
- **Primary constructors** (`class const BirthDate({…})`) aren't `Declaration` nodes: they get
  their own visit, and their declaring parameters (`isDeclaring`) declare fields.
- **Normalized Windows paths** (`C:\…`, not `C:/…`): the collection rejects the others.
- **Enum values.** An enum value has no `ConstructorName` node: count
  `EnumConstantDeclaration.constructorElement`, else `ReminderLead.new` reads unused — d53077f
  (`find_dead_code.dart`, `visitDeclaration`).
- Comments (`visitComment`) and `show`/`hide` combinators aren't uses; arguments map to
  parameters through `argument.correspondingParameter`.

To prove a change, in a worktree, add a throwaway probe file to lib/ and test/ (a dead class, a test-only
member, a parameter never passed, a tear-off, an extension member…), run the finder, read the
sections, and delete the probes.
