---
name: git-workflow
description: "Git workflow for the AnKi Flutter repo: Conventional Commits messages with an UPPERCASE type (`FEAT(scope): subject`, English, imperative, terse), atomic commits, branch names and pull request titles. Use for ANY git operation that writes or publishes history — committing, writing or rewording a commit message, staging and splitting changes into several commits, amending, squashing, creating a branch, pushing, opening or titling a pull request, drafting release notes from history. Trigger even on short or French asks such as « commit », « commite », « fais un commit », « prépare le commit », « message de commit », « renomme le commit », « découpe en plusieurs commits », « crée une branche », « push », « ouvre une PR ». Not for read-only questions about history (git log, blame or diff to explain something)."
---

# AnKi git workflow

History is documentation: scanning `git log` should give an overview of what was done, at a
glance. This repo follows [Conventional Commits](https://www.conventionalcommits.org/) with the
maintainer's house style: **UPPERCASE type** and **terse wording**. Older commits use
`ADD/FIX/UPDATE - ...`; leave them alone, everything new uses the format below.

Talk to the user in their language (French here). Commit messages, branch names and PR titles
are always in **English**, as required by `AGENTS.md`.

## Message format

```
<TYPE>(<scope>): <subject>

<body>

<footer>
```

- **TYPE**: uppercase — `FEAT`, `FIX`, `BUILD`… It is the first thing the eye catches in the log
  and matches the maintainer's habit (the old `ADD/FIX/UPDATE`). The spec treats types as
  case-insensitive, so this stays valid Conventional Commits. The scope stays lowercase.
- **subject**: short and scannable — aim for ≤ 50 characters (72 is the hard limit). Imperative
  mood, lowercase start, no trailing period, no filler (`the`, `some`, `various`, `in order to`).
  It completes *"If applied, this commit will …"*: `upgrade google_fonts to 9.0.0`, not
  `upgraded google_fonts` or `update of the google fonts package`.
- **body** (optional): only when the subject can't carry everything. Short bullets, one change
  per line, ≤ 60 characters, telegraphic (`- Gradle 9.3.1, AGP 9.1.1, Kotlin 2.4.10`). Add a
  *why* bullet only for a non-obvious consequence (a forced adaptation, a migration to run). No
  prose paragraphs, no line-by-line paraphrase of the diff: the reader wants the overview, the
  diff has the details.
- **footer** (optional): `BREAKING CHANGE: <what breaks, how to migrate>`, `Refs #12`.
  Keep any attribution trailer the environment requires (e.g. `Co-Authored-By:`) as the last lines.

### Types

| Type | Use when the commit… |
|---|---|
| `FEAT` | adds a capability the user can see or use |
| `FIX` | corrects wrong behaviour (crash, bug, wrong data, broken test) |
| `REFACTOR` | restructures code with no behaviour change |
| `PERF` | makes something faster or lighter without changing behaviour |
| `TEST` | only adds or fixes tests (`test/`, test support) |
| `STYLE` | only formatting or lint-driven cosmetics, zero logic change |
| `DOCS` | only docs or comments: README, `AGENTS.md`, `shared/*.md`, `PROJECT_CONTEXT.md`, skills |
| `BUILD` | changes the toolchain: Flutter/Dart SDK constraint, Gradle, AGP, Kotlin, Xcode, build scripts |
| `CHORE` | maintenance outside the app logic: pub dependency bumps, config, regenerated assets |
| `CI` | changes CI pipelines |

Tie-breakers, because the choice drives changelogs:
- A dependency bump that forces code changes stays **one** commit (`CHORE(deps)`) so that every
  commit builds; name the adaptation in a body bullet.
- A fix whose test is written at the same time is a `FIX`, not a `TEST`.
- Reformatting the whole codebase after an SDK bump is its own `STYLE` commit — mixing it with
  logic makes the logic impossible to review.
- If you hesitate between `FEAT` and `REFACTOR`, ask: would a user notice? Yes → `FEAT`.

### Scopes

One lowercase scope, derived from where the change lives. Omit it when a commit genuinely spans
several areas (better no scope than a misleading one; never comma-separated lists).

| Path | Scope |
|---|---|
| `lib/features/<feature>/` and its tests | `auth`, `birthday`, `book_scanner`, `home`, `user` |
| `lib/core/theme/` | `theme` |
| other `lib/core/` | `core` |
| `lib/app/` (router, bootstrap, `MaterialApp`) | `app` |
| `lib/l10n/`, `*.arb` | `l10n` |
| `pubspec.yaml`, `pubspec.lock` | `deps` |
| `android/`, `ios/`, `web/` | `android`, `ios`, `web` |
| `firestore.rules`, `firebase.json`, Firebase config | `firebase` |
| `lib/assets/`, launcher icons, splash | `assets` |
| `scripts/` | `scripts` |
| `AGENTS.md`, `CLAUDE.md`, `shared/`, `.claude/` | `agents` |

### Breaking changes

Append `!` after the scope and explain in the footer. In this app it mostly means data or
platform migrations: a Firestore schema change, a raised minimum OS version, a storage format that
invalidates existing data.

```
FEAT(birthday)!: store categories as a subcollection

BREAKING CHANGE: old `categories` arrays are no longer read;
run scripts/migrate_categories.ps1 once per environment.
```

## Committing, step by step

1. **Look before writing.** Run `git status`, `git diff --staged`, `git diff` and
   `git log --oneline -5`. Read the actual changes; a message written from memory of the session
   misses what really landed (formatter runs, generated files, files touched by another session).
2. **Respect the index.** If the user staged something, commit exactly that unless asked otherwise.
   Stage with explicit paths (`git add lib/core/theme/themes.dart`), never a blind `git add -A` /
   `git add .`, which sweeps in scratch files, generated output and other people's work.
3. **One intent per commit.** If the changes mix intents (deps bump + reformat + feature + tests
   of another feature), propose a split before committing — list the commits with their messages
   and the files in each, and let the user validate. Each commit should build and pass tests on
   its own, so that `git bisect` and reverts stay usable. Tests belong with the code they cover.
4. **Check before recording.** For Dart changes, the commit must not break the build:
   `dart format --output=none --set-exit-if-changed <files>` and `flutter analyze`, plus the
   relevant `flutter test` targets when `lib/` or `test/` changed (skip what you already ran
   after the last edit in this session). If something fails, fix it or tell the user — don't
   commit red.
5. **Guard secrets.** Never stage `secrets.json`, `key.properties`, `*.jks`, `*.keystore`, `.env`
   or service-account JSON. `android/app/google-services.json` is tracked on purpose (Firebase
   client config) — commit it only when the change is intended (e.g. a new SHA-1).
6. **Write and commit.** Use a heredoc so the body and trailers keep their line breaks:

   ```bash
   git commit -F - <<'EOF'
   CHORE(deps): upgrade google_fonts to 9.0.0

   - apply Outfit per style in AppTheme
   - why: TextTheme now comes from material_ui
   EOF
   ```

   In PowerShell, pass a single-quoted here-string to `git commit -m @' ... '@`.
   To reword only the last message without sweeping staged files into it, use
   `git commit --amend --only -F -` (unpushed commits only — see Safety).
7. **Report.** Show `git log --oneline -<n>` for the new commits. Mention anything left
   uncommitted on purpose.

## Branches and pull requests

- Branch from an up-to-date `main`: `<type>/<kebab-case-summary>`, all lowercase —
  `feat/gift-wishlist`, `fix/notification-timezone`, `build/agp-9`. Short, no ticket noise, no
  personal prefixes.
- A PR title follows the commit format (it becomes the squash-merge commit):
  `FEAT(book_scanner): suggest gifts from scanned books`.
- PR body, same terse spirit: **Why** (one or two lines), **What** (bullets), **How to test**
  (commands, manual checks on the phone), and any follow-up left out of scope.

## Safety

Ask for an explicit yes before anything that publishes or rewrites history: `git push`,
`--force` / `--force-with-lease`, rebasing or amending commits that are already pushed,
`git reset --hard`, deleting branches. Prefer a new commit over `--amend` unless the user asks.
Never bypass hooks (`--no-verify`) or signing; if a hook fails, fix the cause.

## Examples

Rewriting past messages from this repo's history:

| Before | After |
|---|---|
| `UPDATE - Big refacto architecture yolo` | `REFACTOR: move app wiring to lib/app` |
| `FIX - Try fixing notifications + upgrade dependencies` | two commits: `FIX(core): request notification permission per OS` and `CHORE(deps): bump timezone, contacts, secure storage` |
| `ADD - Settings screen` | `FEAT(user): add settings screen` |
| `UPDATE - Commentaries in source code in French` | `DOCS: translate code comments to French` |

Too wordy vs. scannable:

```
# Too wordy
BUILD: upgrade the Flutter SDK, all the dependencies and the Android toolchain

- AppTheme applies Outfit per style: the google_fonts 9 TextTheme
  comes from material_ui and no longer matches flutter/material

# Scannable
BUILD: upgrade Flutter, deps and Android toolchain

- Flutter 3.47.6, Dart 3.13.5
- Gradle 9.3.1, AGP 9.1.1, Kotlin 2.4.10
- adapt AppTheme to google_fonts 9
```

A session that upgraded the stack, split into reviewable commits:

```
CHORE(deps): pin pub dependencies to latest
BUILD: upgrade Flutter to 3.47.6
STYLE: reformat with Dart 3.13 formatter
BUILD(android): upgrade Gradle, AGP and Kotlin
CHORE(deps): upgrade google_fonts to 9.0.0
TEST: fix tests broken by screens refactor
TEST(theme): cover AppTheme text styles
```
