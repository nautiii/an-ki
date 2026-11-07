---
name: git-workflow
description: "AnKi git workflow: Conventional Commits with an UPPERCASE type (`FEAT(scope): subject`), atomic commits behind the commit gate (checks + reviewer), branch names, rebase-only integration, pull request titles. Use for any git operation that writes or publishes history: commit, reword, split, amend, squash, branch, rebase, push, PR (« commite », « intègre la branche », « pousse », « ouvre une PR »). Not for read-only history questions, nor the review itself (the `reviewer` agent)."
effort: low
---

# AnKi git workflow

History is documentation: scanning `git log` should give an overview of what was done, at a
glance. This repo follows [Conventional Commits](https://www.conventionalcommits.org/) with the
maintainer's house style: **UPPERCASE type** and **terse wording**. Older commits use
`ADD/FIX/UPDATE - ...`; leave them alone, everything new uses the format below. Messages, branch
names and PR titles are in English (`AGENTS.md`).

## Message format

```
<TYPE>(<scope>): <subject>

<body>

<footer>
```

- **TYPE**: uppercase — `FEAT`, `FIX`, `BUILD`… It is the first thing the eye catches in the log
  and matches the maintainer's habit (the old `ADD/FIX/UPDATE`). The spec treats types as
  case-insensitive, so this stays valid Conventional Commits. The scope stays lowercase.
- **subject**: 72 characters at most (aim for about 50; the history averages 47). Imperative
  mood, lowercase start, no trailing period, no filler (`the`, `some`, `various`, `in order to`).
  It completes *"If applied, this commit will …"*: `upgrade Kotlin Gradle plugin to 2.4.21`, not
  `upgraded the Kotlin plugin` or `update of the Kotlin Gradle plugin`.
- **body**: short bullets, one change per line, telegraphic (`- Gradle 9.3.1, AGP 9.1.1`); most
  commits here have one. Add a *why* bullet for a non-obvious consequence (a forced adaptation, a
  migration to run). No prose paragraph, no line-by-line paraphrase of the diff: the reader wants
  the overview, the diff has the details.
- **footer** (optional): `BREAKING CHANGE: <what breaks, how to migrate>`. Keep any attribution
  trailer the environment requires (e.g. `Co-Authored-By:`) as the last lines.

### Types

| Type | Use when the commit… |
|---|---|
| `FEAT` | adds a capability the user (or an agent, for `.claude/`) can see or use |
| `FIX` | corrects wrong behaviour (crash, bug, wrong data, broken test or script) |
| `REFACTOR` | restructures code with no behaviour change |
| `PERF` | makes something faster or lighter without changing behaviour |
| `TEST` | only adds or fixes tests (`test/`, test support) |
| `STYLE` | only formatting or lint-driven cosmetics, zero logic change |
| `DOCS` | only markdown or comments: README, `AGENTS.md`, `.claude/rules/`, skills |
| `BUILD` | changes the toolchain: Flutter/Dart SDK constraint, Gradle, AGP, Kotlin, Xcode, build scripts |
| `CHORE` | maintenance outside the app logic: pub dependency bumps, config, settings, regenerated assets |
| `CI` | changes CI pipelines (none today) |

Tie-breakers, because the choice drives changelogs:
- A dependency bump that forces code changes stays **one** commit (`CHORE(deps)`) so that every
  commit builds; name the adaptation in a body bullet.
- A fix whose test is written at the same time is a `FIX`, not a `TEST`.
- A fix that needs a restructuring: the `REFACTOR` first, behaviour locked by tests, then the
  `FIX` — two commits (`AGENTS.md` › Architecture), so each one reviews and reverts alone.
- Reformatting the whole codebase after an SDK bump is its own `STYLE` commit, right after the
  `BUILD` one — mixing it with logic makes the logic impossible to review.
- If you hesitate between `FEAT` and `REFACTOR`, ask: would a user notice? Yes → `FEAT`.
- Code under `.claude/` (hooks, skill scripts) is code: `FEAT`, `FIX` or `CHORE` (settings),
  never `DOCS`.

### Scopes

One lowercase scope, derived from where the change lives. Omit it when a commit genuinely spans
several areas or touches a root file (`.gitignore`, `analysis_options.yaml`, `README.md`:
`CHORE: …`, `DOCS: …`); better no scope than a misleading one, never comma-separated lists.

| Path | Scope |
|---|---|
| `lib/features/<feature>/` and its tests | the feature's folder name: `auth`, `birthday`, `reminders`… |
| `lib/core/theme/` | `theme` |
| other `lib/core/` | `core` |
| `lib/app/` (router, bootstrap, `MaterialApp`) | `app` |
| `lib/l10n/`, `*.arb` | `l10n` |
| `pubspec.yaml`, `pubspec.lock` | `deps` |
| `android/`, `ios/` | `android`, `ios` |
| `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `test/firestore/`, Firebase config | `firebase` |
| `lib/assets/`, launcher icons, splash | `assets` |
| `scripts/` | `scripts` |
| `.claude/skills/<skill>/` docs | the skill's name: `DOCS(ux-ui): …` |
| `AGENTS.md`, other `.claude/` (hooks, agents, rules, settings, skill scripts) | `agents` |

### Breaking changes

Append `!` after the scope and explain in the footer. In this app it means a platform or data
change that existing installs feel: a raised minimum OS version, a storage format that
invalidates existing data. Firestore rules stricter than what the installed app sends are not
shipped with `!` but held (`firestore.rules.hold`, firebase skill).

## Committing, step by step

1. **Look before writing.** Run `git status`, `git diff --staged`, `git diff` and
   `git log --oneline -5`. Read the actual changes; a message written from memory of the session
   misses what really landed (formatter runs, generated files, files touched by another session).
2. **Respect the index.** If the user staged something, commit exactly that unless asked otherwise.
   If the index holds work you didn't stage (the maintainer stages in parallel), say so and ask;
   never unstage their hunks. Stage with explicit paths (`git add lib/core/theme/themes.dart`),
   never a blind `git add -A` / `git add .`, which sweeps in scratch files, generated output and
   other people's work.
3. **One intent per commit.** If the changes mix intents (deps bump + reformat + feature + tests
   of another feature), propose a split before committing — list the commits with their messages
   and the files in each, and let the user validate. Each commit should build and pass tests on
   its own, so that `git bisect` and reverts stay usable. Tests belong with the code they cover.
4. **Check before recording.** Mandatory, not advice, in every session, side sessions included.
   One review per logical change, the checks on every commit:
   - Stage the whole logical change (step 2), then in parallel: the checks,
     `bash .claude/hooks/verify-index.sh` (Bash in the background, no agent: project norms,
     l10n, format, analysis, tests; prints only failures), and the `reviewer` on the staged diff.
     Its model comes from `bash .claude/hooks/review-model.sh`: over 50 lines or a sensitive zone
     (state, data, reminders, navigation, Firebase, dependencies, platforms, the gate) → Opus at
     high effort, the agent's default; otherwise `model: "sonnet"`, `effort: "medium"`. A
     structural or system change (AGENTS.md) always gets Opus.
   - Apply its findings (blocking ones included), re-stage, run the checks again — no second
     review, which keeps token use reasonable.
   - Commit, as one or several atomic commits (step 3). To split, keep only the first commit's
     paths staged and set the rest aside (`git restore --staged <paths>`, then
     `git stash push --include-untracked -- <paths>`), run the checks on that index, commit,
     `git stash pop`, and go on with the next. The checks must pass on each exact staged index.

   Never commit red; never work around the gate — if it blocks wrongly, tell the user. Commit the
   index as it is, in a call of its own: stage in an earlier call, no paths after `git commit`, no
   `-C` or `cd` (run from the repo folder). What the gate requires for which path, and how it
   records the verdicts: `references/gate.md`.
5. **Guard secrets.** Never stage a secret (the list: `AGENTS.md` › House rules);
   `android/app/google-services.json` is tracked on purpose — commit it only when the change is
   intended (e.g. a new SHA-1).
6. **Write and commit.** Use a Bash heredoc so the body and trailers keep their line breaks:

   ```bash
   git commit -F - <<'EOF'
   BUILD(android): upgrade Kotlin Gradle plugin to 2.4.21

   - why: 2.4.10 was untested with AGP 9.1.1
   EOF
   ```

   Commit from the Bash tool: a PowerShell here-string (`@' … '@`) drops the double quotes git
   receives. To reword only the last message without sweeping staged files into it, use
   `git commit --amend --only -F -` (unpushed commits only — see Safety).
7. **Report.** Show `git log --oneline -<n>` for the new commits. Mention anything left
   uncommitted on purpose.

## Branches and pull requests

- Branch from an up-to-date `main`: `<type>/<kebab-case-summary>`, all lowercase —
  `feat/gift-wishlist`, `fix/notification-timezone`, `build/agp-9`. Short, no ticket noise, no
  personal prefixes. A branch the desktop app created for a worktree (`claude/…`) is renamed
  (`git branch -m <type>/<summary>`) before it is pushed.
- Integrate a branch by rebasing it onto `main`, never with a merge commit: `main` stays linear.
  Rebase the branch (or cherry-pick its commits, skipping any merge commit inside it), check the
  result, then fast-forward `main` (`git merge --ff-only`). From a worktree, `main` is checked out
  in the maintainer's folder: `git -C <main checkout> merge --ff-only <branch>` updates their
  working copy, so ask first.
- Squash without an editor (`git rebase -i` needs one): `git reset --soft <base>`, then one commit
  through the gate (step 4).
- A PR title follows the commit format: `FEAT(book_scanner): suggest gifts from scanned books`.
  The PR lands by rebase, its commits as they are.
- PR body, same terse spirit: **Why** (one or two lines), **What** (bullets), **How to test**
  (commands, manual checks on the phone), and any follow-up left out of scope.

## Safety

Ask for an explicit yes before anything that publishes or rewrites history: `git push`, a
forced push (`--force-with-lease` only, never plain `--force`), rebasing or amending commits that
are already pushed, `git reset --hard`, deleting branches. Prefer a new commit over `--amend` unless the user asks.
Never bypass hooks (`--no-verify`, `-n`) or signing; if a hook fails, fix the cause.

In Claude Code, `.claude/hooks/guard-git.sh` enforces this: it blocks merge commits, `git pull`
without `--rebase`/`--ff-only`, blind `git add`, `git commit -a`, forced pushes without lease (a
`+` refspec included), `--no-verify` and `-n`, and every Firebase command that writes production
except the deploy of committed, emulator-proved rules (firebase skill); it makes the maintainer
confirm a push, `reset --hard`, `clean -f`, discarding all changes, `branch -D`, `stash drop` or
rewriting pushed commits. It also gates `git commit` (step 4, `references/gate.md`). A blocked
command is a signal to change approach, not to work around the guard.

## Examples

Rewriting past messages from this repo's history:

| Before | After |
|---|---|
| `UPDATE - Big refacto architecture yolo` | `REFACTOR: move app wiring to lib/app` |
| `FIX - Try fixing notifications + upgrade dependencies` | two commits: `FIX(core): request notification permission per OS` and `CHORE(deps): bump timezone, contacts, secure storage` |
| `ADD - Settings screen` | `FEAT(settings): add settings screen` |
| `UPDATE - Commentaries in source code in French` | `DOCS: translate code comments to French` |

Too wordy vs. scannable:

```
# Too wordy
BUILD(android): upgrade the Kotlin Gradle plugin to its newest 2.4 patch version

- the previous 2.4.10 version had never been tested by JetBrains with
  the Android Gradle plugin 9.1.1 that the project uses

# Scannable (cdda03c)
BUILD(android): upgrade Kotlin Gradle plugin to 2.4.21

- why: 2.4.10 was untested with AGP 9.1.1
```

The stack upgrade of 2026-11-05, split into reviewable commits (Flutter, formatter, pub, Android):

```
BUILD: upgrade Flutter to 3.47.9
STYLE: reformat with Dart 3.13.7 formatter
CHORE(deps): bump pub dependencies
CHORE(deps): upgrade FlutterFire to firebase_core 5.1.0
BUILD(android): upgrade Kotlin Gradle plugin to 2.4.21
```
