# Security rules — design, tests, review

`firestore.rules` is AnKi's only server-side code: every client request is checked against it,
and nothing else stops a modified app from reading another account's birthdays. Treat a rules
change like a schema change: test first, prove it in the emulator, deploy deliberately.

## Contents
1. What the rules allow today
2. Principles
3. Testing in the emulator
4. Proving a test bites
5. Review checklist
6. Snippets

---

## 1. What the rules allow today

| Path | Read | Create | Update | Delete |
|------|------|--------|--------|--------|
| `user/{uid}` | owner | owner | owner | owner |
| `user/{uid}/categories/{id}` | owner | owner | owner | owner |
| `birthday/{id}`, `books/{id}` | `resource.data.uid` = caller | `request.resource.data.uid` = caller | owner, `uid` unchanged | owner |
| `category/{id}` | any signed-in user | any signed-in user (unused by the app, A16) | nobody | nobody |
| anything else | nobody | nobody | nobody | nobody |

`test/firestore/firestore_rules_test.dart` is the executable version of this table: when they
disagree, the tests win and this table gets fixed.

## 2. Principles

1. **Closed by default.** Every `match` is explicit; no `{document=**}` grant, no
   `allow read, write: if true`, no `request.time` deadline left from a quick start.
2. **Ownership by path for new data.** `user/{uid}/<collection>/{id}` with
   `request.auth.uid == userId`: one condition, no field to forge, queries need no filter.
3. **Ownership by field for the legacy top-level collections** (`birthday`, `books`, until M10):
   read and delete check `resource.data.uid`; create checks `request.resource.data.uid`; update
   checks both and pins the owner (`request.resource.data.uid == resource.data.uid`).
4. **Split `write`** into `create`, `update`, `delete` as soon as their conditions differ — the
   owner pin only makes sense on update.
5. **Rules are not filters.** A query is allowed only if every document it could return is
   allowed: the client must send the owner filter (`where('uid', isEqualTo: uid)`) that mirrors
   the rule. A rule change that adds a condition may require a query change, and the other way
   round.
6. **Shared data is read-only for clients.** Documents everyone reads (predefined groups) are
   written in the console; a client-writable shared collection is an abuse and privacy vector
   (A16).
7. **Validate what protects others, not what protects the app from itself.** Each user only
   reaches their own documents, so field validation (`keys().hasOnly`, types, sizes) buys little
   and couples every schema change to a rules deploy synchronised with old app versions. Add it
   where a user's write can hurt someone else (shared data) or the bill (unbounded sizes, if
   abuse ever shows up).
8. **No `get()`/`exists()` in hot paths.** Each costs a document read per request, and on a
   query per evaluation; prefer ownership in the path or in the document itself.
9. **Functions for repeated conditions** (`isSignedIn()`, `isOwner(uid)`) once a condition
   appears three times; keep the file readable top to bottom, comments in French.

## 3. Testing in the emulator

`test/support/firestore_emulator.dart` talks to the emulator over REST, as the given uid
(unsigned token, accepted by the emulator only) or as nobody (`null`); `seed` writes as the
emulator's admin, bypassing the rules. Each `can…` returns true (allowed) or false (refused by
the rules) and throws on anything else (a malformed request is a test bug, not a refusal).

| App call (SDK) | Harness |
|----------------|---------|
| `doc.get()`, a document stream | `canGet(uid, path)` (an absent document that may be read counts as allowed) |
| `collection.add(data)`, `doc().set(data)` on a new id | `canCreate(uid, path, data)` |
| `doc.update(fields)`, `arrayUnion` / `arrayRemove` included | `canUpdate(uid, path, fields)` with the resulting value |
| `doc.set(data, SetOptions(merge: true))` | `canMerge(uid, path, data)` |
| `doc.delete()`, a batch delete | `canDelete(uid, path)` |
| a query or collection stream | `canQuery(uid, collectionPath, whereField:, isEqualTo:, orderByDescending:)` |

Writing tests:
- One `group` per path, named after it (`birthday/{id}`); tests say what the rule guarantees
  (« is listed only through the owner filter »).
- For every access path a repository uses: the owner allowed, another user refused, a
  signed-out caller refused. For field ownership: create with someone else's `uid`, update
  changing `uid`, a query without the filter.
- `setUp` clears the emulator; seed only what the test reads. Fixtures are functions
  (`birthdayOf(owner)`) so tests can't share mutated maps.
- Test first: add the cases, see them fail against the current rules, then change the rules.

Running: `& .\scripts\test_firestore_rules.ps1` from the PowerShell tool or the Terminal panel
(from Bash: `powershell.exe -NoProfile -File scripts/test_firestore_rules.ps1`). Arguments go to
`flutter test` (`--plain-name "never changes owner"`). The script finds Java 21+, applies the
MSIX workaround in Claude's shells, starts the emulator on `demo-anki`, runs `test/firestore/`,
and stops it; exit code 0 means all green. Plain `flutter test` skips these tests.

Compiling: the emulator accepts invalid rules at start and answers every request with
`HTTP 400 … Error compiling rules: L<line>:<col> …` (the harness shows it in each failing test).
Production's compiler gives the same diagnosis without releasing anything:
`firebase deploy --only firestore:rules --dry-run --non-interactive --project an-ki-9b02b`
(« compiled successfully », or `[E] 43:45 - mismatched input ';' …`). Run it before every
handoff: the maintainer's deploy then can't fail on syntax.

## 4. Proving a test bites

A green test that would stay green with a broken rule protects nothing. For a new or loosened
rule, weaken it in a **copy** and run the tests against the copy (never edit `firestore.rules`
in place: the maintainer works in the same tree):

```powershell
$work = "<scratchpad>\rules-mutation"   # a folder outside the repo
New-Item -ItemType Directory -Force $work | Out-Null
$rules = (Get-Content firestore.rules -Raw) -replace '&& request\.resource\.data\.uid == resource\.data\.uid', ''
# WriteAllText : UTF-8 sans BOM. Set-Content -Encoding utf8 (PowerShell 5.1) en
# ajoute un, et l'émulateur refuse alors les règles.
[IO.File]::WriteAllText("$work\firestore.rules", $rules)
[IO.File]::WriteAllText("$work\firebase.json",
  '{"firestore":{"rules":"firestore.rules"},"emulators":{"firestore":{"port":8080},"singleProjectMode":true}}')
& .\scripts\test_firestore_rules.ps1 -Config "$work\firebase.json"   # must fail
```

Check the copy really differs (`(Get-Content firestore.rules -Raw) -ne $rules`) before trusting
a green result: a pattern that matches nothing tests the unchanged rules. On
2026-10-25 four mutations — owner not pinned, birthdays readable by anyone signed in, shared
groups editable, private groups open to others — each failed at least one test.

## 5. Review checklist

- [ ] Every path the repositories touch (`schema.md`) has a `match`; nothing else is open.
- [ ] No `if true`, no `{document=**}` grant, no `request.time` expiry.
- [ ] Every allow on user data requires `request.auth != null` and an ownership check.
- [ ] Field ownership: create checks `request.resource.data.uid`, update pins it, read and
      delete check `resource.data.uid`.
- [ ] Queries in the repositories carry the filter the rules need (rules are not filters).
- [ ] Shared collections are read-only for clients.
- [ ] Each access path has tests: owner allowed, other user and signed-out refused; the new
      rule was shown to fail a test when weakened.
- [ ] `firestore.rules` comments in French explain *why* a condition exists.
- [ ] The report says what the maintainer must deploy, and what to check on the device after.

## 6. Snippets

```
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // Données privées : la propriété vient du chemin.
    match /user/{userId}/ideas/{ideaId} {
      allow read, write: if isOwner(userId);
    }

    // Données partagées : lues par tous les connectés, écrites dans la console.
    match /category/{categoryId} {
      allow read: if isSignedIn();
    }
  }
}
```

Owner pinned on a field-owned document:

```
allow update: if isSignedIn()
  && resource.data.uid == request.auth.uid
  && request.resource.data.uid == resource.data.uid;
```

Validation, where it protects others (principle 7):

```
allow create: if isSignedIn()
  && request.resource.data.keys().hasOnly(['name', 'icon'])
  && request.resource.data.name is string
  && request.resource.data.name.size() <= 40;
```
