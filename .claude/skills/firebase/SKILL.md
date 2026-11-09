---
name: firebase
description: "AnKi's Firebase backend (an-ki-9b02b, Auth + Firestore): security rules and their emulator tests, rules deploy, data map, indexes, migrations, account deletion, guest takeover, console steps. Use for any change or question on firestore.rules, firestore.indexes.json, firebase.json, a collection, field or query, permission-denied, SHA-1, flutterfire (« règles Firestore », « teste les règles », « supprime le compte »). Not for repository code (architecture), screens (ux-ui) or the Android emulator (device)."
effort: high
---

# AnKi's Firebase backend

You own AnKi's backend: the data shape, who may touch it, and how it changes without losing a
birthday. AnKi has no server code — Firestore security rules are the only wall between one
user's data and everyone else's, so they get the rigour of code: written test first, proved in
the emulator, deployed deliberately. Talk French to the maintainer; files and commits stay in
English (git-workflow skill).

## Who does what

| Agents | The maintainer only |
|--------|---------------------|
| Edit `firestore.rules`, `firestore.indexes.json`, `firebase.json`, the repositories | Deploy indexes, and anything else than the rules, to `an-ki-9b02b` |
| Run the emulator and `test/firestore/` (`scripts/test_firestore_rules.ps1`) | Anything in the Firebase or Google Cloud console |
| Local and read-only CLI commands, as the guard lets them through (below) | `firebase login`, deletes, imports, exports of user data |
| Compile rules on the server: `firebase deploy --only firestore:rules --dry-run --non-interactive --project an-ki-9b02b` (releases nothing) | Run a data migration on production data |
| Deploy `firestore.rules` once committed and proved in the emulator (Workflow D) | Lift a deploy hold (`firestore.rules.hold`) once its steps are done |
| Prepare the exact commands and checks for a handoff | |

The guard (`.claude/hooks/guard-git.sh`, the source of truth) lets through local and read-only
commands (emulators, `firestore:indexes`, `apps:sdkconfig`, `use`, `--version`, help,
`deploy --dry-run --only firestore…`) and the rules deploy of Workflow D; everything else is the
maintainer's. Never ask for, store or use a service-account key; never point the emulator at `an-ki-9b02b` (tests
use `demo-anki`, which can't reach production).

## The backend at a glance

- **Auth**: Google, e-mail/password (reset link), anonymous; linking a guest to Google keeps its
  uid. A guest whose Google account already exists opens that account instead (d99cce9,
  c626403): the guest marks its documents `transferTo` with the address, then that account,
  address verified, takes them over or deletes duplicates (`isMarkedFor`, `isTakenOver`;
  addresses compared case-insensitively, else a capitalised Google address leaves them
  orphaned). An unverified address is refused (`GuestMergeFailure.incomplete`); on a duplicate
  the guest's photo, `wishedYears` and own reminders are lost (ux D29, open). Optional biometric
  lock: a token on the profile document.
- **Firestore** (standard edition, offline persistence on): `user/{uid}` and its
  `categories` subcollection; top-level `birthday`, `books` (owned through a `uid` field) and the
  shared `category`. Photos are base64 inside birthday documents.
- **Files**: `firestore.rules`, `firestore.indexes.json` (a copy of production's),
  `firebase.json` (rules, indexes, emulator on port 8080), `test/firestore/firestore_rules_test.dart`
  with its client `test/support/firestore_emulator.dart`, `scripts/test_firestore_rules.ps1`.
- **What remains** lives in `references/backlog.md`: console steps and open decisions. Read it before
  Firebase work; keep it current.

## Read first

| When | Read |
|------|------|
| Before any Firebase work, « que reste-t-il ? » | `references/backlog.md` |
| Any change to data: collection, field, query, deletion | `references/schema.md` — the map, kept in sync with the repositories |
| Writing, reviewing or testing rules | `references/rules.md` |
| A guest whose Google account already exists (ux B5.5) | `references/schema.md` §10 |
| Renaming, retyping or moving data; the 2026-11-04 groups move; M10 | `references/migrations.md` |
| Deploying the rules after a change | Workflow D below |
| Deploying indexes, SHA-1, flutterfire, providers, API keys, budget | `references/console.md` — the maintainer's runbooks |
| Repository code (mapping, failures, batches) | architecture skill, `references/patterns.md` §4 |

## Workflow A — change the data

1. **Map it.** New collection, field or query: update `references/schema.md` first — path,
   owner, fields and types, who writes and reads, index, deletion. A shape decided in the map is
   cheaper than one discovered in a repository.
2. **Size it.** Ceremony: `AGENTS.md` › Working agreement (a field is local, a collection
   structural, moving or rewriting data system); migrations: `references/migrations.md`.
3. **Test the rule first.** Add the access paths to `test/firestore/firestore_rules_test.dart` —
   the owner allowed, another user and a signed-out caller refused, every query shape the
   repository will send — and watch them fail in the emulator. Then write the rule.
4. **Repository** per `.claude/rules/data.md` and architecture `references/patterns.md` §4, with
   a repository test on an old-shape document.
5. **Index.** A query mixing `where` and `orderBy` on different fields (or several range
   filters) needs a composite index: add it to `firestore.indexes.json` in the same change. The
   emulator serves every query, so only this step catches it.
6. **Deletion.** `AccountDeletion` must erase the path, with a test: `references/schema.md` §8.
7. **Verify** (below), commit (git-workflow), then **deploy the rules** (Workflow D) — or, for
   rules the installed app isn't ready for, commit a hold and hand off. Indexes and console
   steps stay a handoff: the exact commands. Either way, a line in `migration.md` §1 for what
   to check on the device until it's checked.

## Workflow B — review or audit

For « nos règles sont-elles sûres ? », a rules diff or a data question: read `firestore.rules`
against the map, walk the checklist in `references/rules.md` §5, run the tests, and report
findings by severity — what leaks or breaks, to whom, the fix and its test. Compare with
production only through what the maintainer can see (console Rules tab, its date and history).

## Workflow C — diagnose a Firebase error

Reproduce on the emulator or the phone (device skill: logcat), then:

| Symptom | Usual cause | Fix |
|---------|-------------|-----|
| `PERMISSION_DENIED` on a query | no `uid` filter (rules are not filters), wrong path, or rules not deployed | add the filter; compare the path with the map; deploy the rules (Workflow D) |
| `PERMISSION_DENIED` right after launch | the session isn't restored yet: `request.auth` is null | derive the stream from `currentUidProvider` |
| `FAILED_PRECONDITION … requires an index` | missing composite index (the log carries a console link) | add it to `firestore.indexes.json`; the maintainer deploys |
| A write that never finishes | offline: write futures resolve on server acknowledgement only | don't await it in the UI (patterns §9) |
| An item that appears, then vanishes | the server refused an optimistic write (rules not deployed? a hold?) | check the rules in production and `firestore.rules.hold`, listen to the controller's error |
| Google sign-in fails at once with a configuration error in logcat (`ApiException: 10`, « Developer console is not set up correctly ») | the signing key's SHA-1 isn't registered | console runbook §4 |
| `requires-recent-login` on account deletion | Auth wants a recent sign-in | account deletion confirms the identity first (`AuthController.confirmIdentity`); elsewhere, re-authenticate before a sensitive operation |

## Workflow D — deploy the rules

Rules changed by an evolution are deployed by the agent that changed them, as the last step of
that change: no handoff. `guard-git.sh` lets `firebase deploy --only firestore:rules --project
an-ki-9b02b` through (alone in its command, from the repo folder, options unquoted and given
once) only when: it holds one `--only firestore:rules` and one `--project an-ki-9b02b`, no
`-f`/`--force`/`-c`/`--config`; it is alone in its call; `firestore.rules` and `firebase.json`
have no uncommitted diff; HEAD's rules equal `main`'s with `main` an ancestor of HEAD; a full run
of `scripts/test_firestore_rules.ps1` passed on that exact content (it writes the marker
`<git-dir>/anki-checks/<blob>.rules`, one per worktree); and no `firestore.rules.hold` sits at
the root or on `main`.

1. **Compatible?** The new rules must accept every request the installed app sends: the
   maintainer's devices run the last APK they installed, not HEAD. Loosening a rule, a new path
   or collection: compatible. A rule that refuses what today's app does (a narrower read, a
   required field, a removed path): not. Then commit a `firestore.rules.hold` (first line: the
   reason; then why, and how to lift it) with its runbook in `references/console.md`, and stop:
   the maintainer deletes the hold once the app and the data are ready
   (the move of the older shared groups was one, lifted on 2026-11-04: `console.md` §10).
2. **Committed and on `main`.** The rules change is committed (checks, reviewer;
   git-workflow skill) and integrated in `main` (a branch rebased, `--ff-only`). A working
   copy or a branch alone is never deployed.
3. **Proved.** `scripts/test_firestore_rules.ps1` in full (no filter, no `-Config`) on that
   commit, then the `--dry-run` compilation (Verify).
4. **Deploy**: `firebase deploy --only firestore:rules --non-interactive --project an-ki-9b02b`
   — « released rules firestore.rules to cloud.firestore ». In a sandboxed session, see the
   proxy gotcha below.
5. **After**: new requests use them within a minute, open listeners within ten. Delete the
   matching line of `references/backlog.md`, keep the device checks in
   `architecture/references/migration.md` §1 until done, and report what was deployed (commit).

Rollback: the maintainer restores the previous version from the console Rules tab history
(one click); the fix then goes through this workflow.

## Verify — show, don't claim

- **Rules**: `& .\scripts\test_firestore_rules.ps1` (PowerShell tool or Terminal panel; from Bash
  `powershell.exe -NoProfile -File scripts/test_firestore_rules.ps1`) — about 2 min, mostly `flutter test` compiling (27 tests on 2026-11-09).
  For a new or loosened rule, prove the test bites: weaken the rule in a scratch copy and watch a
  test fail (`references/rules.md` §4). Never edit `firestore.rules` in place for that: the
  maintainer works in the same tree.
- **Compilation** before any handoff: `firebase deploy --only firestore:rules --dry-run
  --non-interactive --project an-ki-9b02b` prints « compiled successfully », or each error as
  `[E] line:column`. Production's compiler is the reference; nothing is released.
- **Code**: `bash .claude/hooks/verify-index.sh`, then the touched repositories' tests
  (`test/firestore/` skips itself without the emulator).
- **Indexes**: `firestore.indexes.json` still parses and still holds production's indexes.
- **Production behaviour** (rules deployed, an index built, a migration run): only on a device,
  after the deploy or the maintainer's step — say it wasn't checked until then.

## Report (French)

```
## <Changement> — <objectif>
**Données** — chemins, champs, requêtes ; references/schema.md mis à jour
**Règles et index** — ce qui change, pour qui ; tests ajoutés (n), mutations détectées
**Vérifications** — tests de règles · analyze · tests · appareil (ou « non vérifié »)
**Déploiement** — règles déployées (commit) ou retenues (firestore.rules.hold, pourquoi)
**À faire par toi** — commandes exactes (index, console…) et contrôle après coup
**Suite** — dette ouverte, migration.md mis à jour
```

## Gotchas

- `FakeFirebaseFirestore` can't judge AnKi's rules: its rules engine has no `resource` nor
  `request.resource`. Repository tests prove mapping and queries; only `test/firestore/` proves
  access.
- On `update`, rules see the merged document (field transforms like `arrayUnion` applied):
  checks on `request.resource.data` hold for partial updates too.
- Firestore never cascades and deleting the Auth account leaves every document: order and
  completeness are `AccountDeletion`'s job (`references/schema.md` §8).
- What the script handles, so you don't: the CLI sometimes pushes the rules while the emulator
  starts (« Change detected, updating rules… » then « Failed to make request … securityRules »)
  and leaves it running — the script stops what it started and retries once. It refuses to start
  when port 8080 is taken and says by whom (a leftover emulator: `Stop-Process -Id <pid>`).
- Invalid rules show in every test as `HTTP 400 … Error compiling rules: L43:45 …`, or as that
  `securityRules` failure twice; the server compilation above gives the exact error.
- Copies of the rules written from PowerShell 5.1: `[IO.File]::ReadAllText` / `WriteAllText`.
  `Get-Content` misreads the French comments (UTF-8 without BOM) and `Set-Content -Encoding utf8`
  adds a BOM the emulator chokes on: every request then fails.
- `firebase emulators:exec` runs its script through `cmd` on Windows (`%VAR%`, not `$VAR`) and
  writes `firestore-debug.log` at the root (git-ignored).
- Claude's shells are sandboxed (MSIX): Java can't open its AF_UNIX socket under AppData. The
  script sets `-Djdk.net.unixdomain.tmpdir` in `JAVA_TOOL_OPTIONS`, only when that variable is
  empty and `CLAUDECODE` is set; the Terminal panel needs nothing.
- The emulator needs Java 21+ (the script finds one in the PATH, `JAVA_HOME` or `~/.jdks`); its
  first start downloads ~140 MB to `~/.cache/firebase/emulators`.
- `firestore.indexes.json` must mirror production: re-export it
  (`firebase firestore:indexes --project an-ki-9b02b > firestore.indexes.json`) before editing;
  deploying a file without a production index offers to delete it.
- Dates are stored as the instant of a local midnight (`Timestamp.fromDate(DateTime(y, m, d))`):
  read in a timezone further west, a birthday can move to the day before. Keep it in mind for
  any new date field; M10 plans `day`/`month`/`year` instead.
- Limits that shape the data: `.claude/rules/data.md` and architecture `references/patterns.md`
  §4 (1 MiB, 500 operations per batch); 30 values in an `in` or `array-contains-any` filter.
- A delayed write behind « Annuler » keeps the uid it started with (architecture
  `references/patterns.md` §15; efa0dd6, bcaa4f6).
- Sandboxed Claude Code sessions set `HTTP_PROXY`/`HTTPS_PROXY`, and firebase-tools 15.34.1 on
  Node 26 then fails every production request with `InvalidArgumentError: invalid onError
  method` (shown as « Failed to make request to https://firebaserules.googleapis.com/… »;
  `--debug` shows the undici error). Run the command alone (no `cd`, pipe or `&&`: `guard-git.sh`
  refuses them for a deploy), outside the sandbox, with the proxy emptied for that command:
  `HTTPS_PROXY= HTTP_PROXY= firebase deploy --only firestore:rules --non-interactive --project
  an-ki-9b02b`; same for the `--dry-run`. The emulator is unaffected.
