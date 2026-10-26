---
name: firebase
description: "AnKi's Firebase backend (project an-ki-9b02b: Auth and Cloud Firestore, no Storage): security rules proved in the Firestore emulator, the map of every collection and field, composite indexes, schema changes and data migrations, account deletion that leaves nothing behind, and the console steps only the maintainer runs (deploying rules and indexes, SHA-1, flutterfire configure, sign-in providers, API keys). Use for ANY change or question touching firestore.rules, firestore.indexes.json, firebase.json, a new collection, field or query, a permission-denied or missing-index error, who can read which data, a migration, or Firebase console setup. Trigger even on French asks: « règles Firestore », « déploie les règles », « index », « migration de données », « permission denied », « la connexion Google échoue », « SHA-1 », « flutterfire ». Not for repository code patterns (architecture) or screens (ux-ui)."
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
| Edit `firestore.rules`, `firestore.indexes.json`, `firebase.json`, the repositories | Deploy rules and indexes to `an-ki-9b02b` |
| Run the emulator and `test/firestore/` (`scripts/test_firestore_rules.ps1`) | Anything in the Firebase or Google Cloud console |
| Read-only CLI on production: `firestore:indexes`, `projects:list`, `apps:list`, `login:list` | `firebase login`, deletes, imports, exports of user data |
| Compile rules on the server: `firebase deploy --only firestore:rules --dry-run --non-interactive --project an-ki-9b02b` (releases nothing) | Run a data migration on production data |
| Prepare the exact commands and checks for a handoff | |

`.claude/hooks/guard-git.sh` lets only these `firebase` commands through (plus `--help`). Never
ask for, store or use a service-account key; never point the emulator at `an-ki-9b02b` (tests
use `demo-anki`, which can't reach production).

## The backend at a glance

- **Auth**: Google, e-mail/password (reset link), anonymous; linking a guest to Google keeps its
  uid. Optional biometric lock: a token on the profile document.
- **Firestore** (standard edition, offline persistence on): `user/{uid}` and its
  `categories` subcollection; top-level `birthday`, `books` (owned through a `uid` field) and the
  shared `category`. Photos are base64 inside birthday documents.
- **Files**: `firestore.rules`, `firestore.indexes.json` (a copy of production's),
  `firebase.json` (rules, indexes, emulator on port 8080), `test/firestore/firestore_rules_test.dart`
  with its client `test/support/firestore_emulator.dart`, `scripts/test_firestore_rules.ps1`.
- **What remains** lives in `references/backlog.md`: the rules in git are ahead of production
  (F1), debts A16 and A17, console steps. Read it before Firebase work; keep it current.

## Read first

| When | Read |
|------|------|
| Before any Firebase work, « que reste-t-il ? » | `references/backlog.md` |
| Any change to data: collection, field, query, deletion | `references/schema.md` — the map, kept in sync with the repositories |
| Writing, reviewing or testing rules | `references/rules.md` |
| Renaming, retyping or moving data; A16; M10 | `references/migrations.md` |
| Deploying, SHA-1, flutterfire, providers, API keys, budget | `references/console.md` — the maintainer's runbooks |
| Repository code (mapping, failures, batches) | architecture skill, `references/patterns.md` §4 |

## Workflow A — change the data

1. **Map it.** New collection, field or query: update `references/schema.md` first — path,
   owner, fields and types, who writes and reads, index, deletion. A shape decided in the map is
   cheaper than one discovered in a repository.
2. **Size it** (`AGENTS.md`). A new optional field read tolerantly is local. A new collection or
   a path change is structural: brief first. Moving or rewriting existing documents is a
   migration — system: brief and approval (`references/migrations.md`).
3. **Test the rule first.** Add the access paths to `test/firestore/firestore_rules_test.dart` —
   the owner allowed, another user and a signed-out caller refused, every query shape the
   repository will send — and watch them fail in the emulator. Then write the rule.
4. **Repository** per the architecture skill: tolerant read, client-side ids and clock, batches
   of ≤ 500, a repository test with an old-shape document.
5. **Index.** A query mixing `where` and `orderBy` on different fields (or several range
   filters) needs a composite index: add it to `firestore.indexes.json` in the same change. The
   emulator serves every query, so only this step catches it.
6. **Deletion.** Every per-user path is erased by `AccountDeletion` — subcollections one by one,
   Firestore never cascades — with a test.
7. **Verify** (below), then **hand off**: the exact deploy commands, what to check on the
   device afterwards, and a line in `migration.md` §1 until it's checked.

## Workflow B — review or audit

For « nos règles sont-elles sûres ? », a rules diff or a data question: read `firestore.rules`
against the map, walk the checklist in `references/rules.md` §5, run the tests, and report
findings by severity — what leaks or breaks, to whom, the fix and its test. Compare with
production only through what the maintainer can see (console Rules tab, its date and history).

## Workflow C — diagnose a Firebase error

Reproduce on the emulator or the phone (device skill: logcat), then:

| Symptom | Usual cause | Fix |
|---------|-------------|-----|
| `PERMISSION_DENIED` on a query | no `uid` filter (rules are not filters), wrong path, or rules not deployed | add the filter; compare the path with the map; ask for a deploy |
| `PERMISSION_DENIED` right after launch | the session isn't restored yet: `request.auth` is null | derive the stream from `currentUidProvider` |
| `FAILED_PRECONDITION … requires an index` | missing composite index (the log carries a console link) | add it to `firestore.indexes.json`; the maintainer deploys |
| A write that never finishes | offline: write futures resolve on server acknowledgement only | don't await it in the UI (patterns §9) |
| An item that appears, then vanishes | the server refused an optimistic write (rules not deployed?) | check the rules in production, listen to the controller's error |
| Google sign-in fails at once with a configuration error in logcat (`ApiException: 10`, « Developer console is not set up correctly ») | the signing key's SHA-1 isn't registered | console runbook §4 |
| `requires-recent-login` on account deletion | Auth wants a recent sign-in (debt A17) | re-authenticate first; never erase data before the account can go |

## Verify — show, don't claim

- **Rules**: `& .\scripts\test_firestore_rules.ps1` (PowerShell tool or Terminal panel; from Bash
  `powershell.exe -NoProfile -File scripts/test_firestore_rules.ps1`) — about 15 s, all green.
  For a new or loosened rule, prove the test bites: weaken the rule in a scratch copy and watch a
  test fail (`references/rules.md` §4). Never edit `firestore.rules` in place for that: the
  maintainer works in the same tree.
- **Compilation** before any handoff: `firebase deploy --only firestore:rules --dry-run
  --non-interactive --project an-ki-9b02b` prints « compiled successfully », or each error as
  `[E] line:column`. Production's compiler is the reference; nothing is released.
- **Code**: `dart format`, `flutter analyze`, `dart analyze`, the touched repositories' tests,
  then the whole suite (`test/firestore/` skips itself without the emulator).
- **Indexes**: `firestore.indexes.json` still parses and still holds production's indexes.
- **Production behaviour** (rules deployed, an index built, a migration run): only on a device,
  after the maintainer's step — say it wasn't checked until then.

## Report (French)

```
## <Changement> — <objectif>
**Données** — chemins, champs, requêtes ; references/schema.md mis à jour
**Règles et index** — ce qui change, pour qui ; tests ajoutés (n), mutations détectées
**Vérifications** — tests de règles · analyze · tests · appareil (ou « non vérifié »)
**À faire par toi** — commandes exactes (deploy…) et contrôle après coup
**Suite** — dette ouverte, migration.md mis à jour
```

## Gotchas

- `FakeFirebaseFirestore` can't judge AnKi's rules: its rules engine has no `resource` nor
  `request.resource`. Repository tests prove mapping and queries; only `test/firestore/` proves
  access.
- On `update`, rules see the merged document (field transforms like `arrayUnion` applied):
  checks on `request.resource.data` hold for partial updates too.
- Deleting `user/{uid}` leaves `user/{uid}/categories` in place, and deleting the Auth account
  leaves every document: order and completeness are `AccountDeletion`'s job.
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
- Claude's shells are sandboxed (MSIX): Java can't open its loopback socket under AppData. The
  script sets `JAVA_TOOL_OPTIONS` when `CLAUDECODE` is set; the Terminal panel needs nothing.
- The emulator needs Java 21+ (the script finds one in the PATH, `JAVA_HOME` or `~/.jdks`); its
  first start downloads ~140 MB to `~/.cache/firebase/emulators`.
- `firestore.indexes.json` must mirror production: re-export it
  (`firebase firestore:indexes --project an-ki-9b02b > firestore.indexes.json`) before editing;
  deploying a file without a production index offers to delete it.
- Dates are stored as the instant of a local midnight (`Timestamp.fromDate(DateTime(y, m, d))`):
  read in a timezone further west, a birthday can move to the day before. Keep it in mind for
  any new date field; M10 plans `day`/`month`/`year` instead.
- Limits that shape the data: 1 MiB per document (base64 photos), 500 operations per batch,
  30 values in an `in` or `array-contains-any` filter.
