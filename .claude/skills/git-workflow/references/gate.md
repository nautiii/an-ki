# The commit gate — how `guard-git.sh` decides

`SKILL.md` step 4 says what to do; this file says what the hook checks, so a refusal can be read
and fixed. The scripts are the source of truth: `.claude/hooks/guard-git.sh` (the gate),
`verify-index.sh` (the checks), `record-review.sh` and `review-model.sh` (the review). Self-test of
the gate: `bash .claude/hooks/test-guard-git.sh`.

## What a commit needs

- **Code** needs the checks' verdict for the exact staged index and a review covering its paths.
  Code is what `guard-git.sh` matches: anything under `lib/`, `test/`, `android/`, `ios/`;
  `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `l10n.yaml`, `firestore.rules`,
  `firestore.indexes.json`, `firebase.json`; and every `.dart` or `.arb` file wherever it lives,
  the scripts under `.claude/skills/*/scripts/` included.
- **Any other non-markdown path** (hooks, settings, `.gitignore`, PowerShell scripts) needs a
  review.
- **Markdown only** needs nothing.

## How the verdicts are recorded

- The checks record their verdicts themselves, never from an agent's message:
  `verify-index.sh` records one for the staged index once everything passes on an index that
  didn't move and that the working copy matches; otherwise it checks the working copy and records
  nothing. A code file that differs from the index, or an untracked one under `lib/` or `test/`,
  therefore blocks the verdict: set it aside first (`SKILL.md` step 4).
- The reviewer ends its review with `bash .claude/hooks/record-review.sh` (refused outside the
  reviewer), which records the base commit and the staged paths. Stage nothing while it runs: it
  records the index as it stands when it finishes.
- A review covers each path it saw until that path is committed (an `--amend` reopens the last
  commit's), plus new test files, while its base stays an ancestor of HEAD, for 48 hours at most.
  Anything else needs a new review: the next change, a path already committed (a file split
  across two commits included), a path the review didn't see (tell the reviewer which paths are
  new).

## What the call itself must look like

- One `git commit` per call, and nothing else in that call touches the index (`add`, `rm`,
  `restore`, `stash`…): the gate judges the index as it stands before the call. Stage in an
  earlier call.
- No paths after `git commit`, no `-C`, `--git-dir` or `cd`: the repository checked is the one of
  the call's folder.
- A heredoc's body is ignored, what follows its closing line is checked like any other command
  (fixed on 2026-11-07: until then everything after the first `<<` escaped the guard).

## Worktrees and older branches

In a worktree session the hooks run the main checkout's scripts (`$CLAUDE_PROJECT_DIR`, the
payload's `cwd` being the worktree): a hook change applies once it is on main. A branch older than
the check scripts runs the main checkout's ones from its own folder, or rebases on main.

## Limits

The gate protects against forgetting, not against deliberate bypass (`git commit-tree`,
`bash -c`, another tool than git, a path written to `anki-checks` by hand…). Other agents than
Claude Code run the same scripts, or the checks by hand:
`dart format --output=none --set-exit-if-changed <files>`, `dart analyze --fatal-infos` and
`flutter test`.
