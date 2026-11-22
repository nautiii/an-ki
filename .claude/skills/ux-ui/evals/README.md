# ux-ui evals

Three cases, one per core job: capture (`capture-contact-import`), act on it
(`wish-belated-catch-up`), identity (`groups-page-identity`). Run with the skill-creator skill;
results live in `build/ux-ui-workspace/iteration-<N>/` (git-ignored).

## Base commit: 2d9d96f

Every prompt describes the app as it is at **2d9d96f** (person page, quick add and suggested
wishes shipped). Run each case in a detached worktree at that commit, never on the moving
`main`, so that iterations compare like with like:

```bash
git worktree add --detach build/evals-wt/<case>-<config> 2d9d96f
# replace .claude/skills/ux-ui/ there with the version under test, without its evals/
cd build/evals-wt/<case>-<config> && flutter pub get --offline
```

Remove the `evals/` folder from the copy under test: a run that reads its graders measures
nothing. Before removing a worktree, copy what the graders read into the run's `outputs/`: the
brief (`answer.md`), `build/ui_snapshots/` (captures, `boards/`, `_src/` prototypes), the
audit logs and the worktree's `git status --short`. Then remove every worktree
(`git worktree remove --force`). When the screens a
prompt names are rebuilt on `main`, move the cases to a newer base or to screens still to do,
and say so here.

## Criteria

Graders 01–03 and 05–07 are the same sentence in every case; 04 (states) and 08 are the case's
own. They judge what a senior designer does whatever the skill's documents say: steps counted
against a target, candidates rendered and decided on a measurement, structure diagnosed, states
designed, contrast measured, colours from the theme, checks shown rather than claimed. None
checks a decision that only the skill's backlog records (a given pattern, a given number of
suggestions): that would test the document's memory, not judgment.

- `Colors.transparent` is accepted (the theme uses it); scaffolding around the app (a fake
  keyboard, a comparison board) is out of the theme-roles criterion.
- Re-grading iteration 1's outputs with 01–03 and 05–07: 01, 02 and 05 separated the two skill
  versions; 03, 06 and 07 passed everywhere. They stay as guards (the house rules and the « show,
  don't claim » rule), not as evidence that one version is better.
- 08 in `wish-belated-catch-up` judges the shipped day-after behaviour (the « Hier » card, its
  belated message, « a eu N ans ») as the starting point; another reasonable format, argued, is
  not a failure.

History: iteration 1 (2026-11-19) ran three cases that asked to design what has since shipped
(P7 + P8, P4 + P6, P10), at commit 7d1c995; iteration 2 moved to the cases above.
