# Migrations — changing data that already exists

AnKi has no server code and no Admin SDK in the repo. Existing documents change in only two
ways: the app rewrites the signed-in user's own documents, through the rules (a *lazy*
migration), or the maintainer runs a one-off operation with admin rights. Prefer the first:
it is tested like any app code and needs no key. Either way, moving data is a **system** change
(`AGENTS.md`): brief first (§7), build after an explicit go.

## Contents
1. Is it a migration?
2. Additive changes — the default
3. Lazy migration in the app
4. Migration run by the maintainer
5. Plan A16 — older groups out of the shared collection
6. Plan M10 — per-user collections
7. Brief

---

## 1. Is it a migration?

| Change | Migration? | How |
|--------|-----------|-----|
| New optional field | no | tolerant read with a default, written from now on |
| New field whose default suits old documents | no | the default lives in the mapper (`yearKnown` absent → `true`) |
| Replace a field | not always | write the new one and delete the old on the next write (`themeMode` replacing `isDark`); read both until no old document can remain |
| Rename or retype a field everywhere | yes | dual read, write the new shape, clean up later |
| Move documents to another path | yes | lazy copy with the same ids, dual read, rules for both paths during the overlap |
| Tighten a rule on existing data | maybe | check that no existing document (old shapes included) breaks the new rule before deploying it |

## 2. Additive changes — the default

The mapper reads the absent field as a default, the repository writes it from now on, a
repository test feeds an old-shape document, and `schema.md` §9 lists the shape still read.
No script, no deploy coupling, nothing to roll back. Most changes should end here.

## 3. Lazy migration in the app

For data the user owns and the rules let them read in the old place and write in the new one.

- **What to migrate** is a pure domain function (old documents in, new documents out), tested
  without Firebase.
- **The copy** is a repository method: same document ids, `set` (never `add`, so a retry can't
  duplicate), batches of ≤ 500 (`writeInBatches`), idempotent — run twice, nothing changes.
- **When**: in `app/bootstrap`, once the session exists (`currentUidProvider` non-null), at most
  once per session. A marker on the profile (`migrations: ['a16']`) saves the check when it
  would cost many reads; skip it when the check is cheap.
- **Offline**: the writes wait in Firestore's cache; idempotency lets the next session finish
  the job if the app stops first.
- **Overlap**: the UI reads both places and merges by id, so a half-migrated account looks
  whole. The rules allow the new path *before* the release that writes it, and close the old
  one only once every device in use runs the new version — for AnKi, ask the maintainer which
  devices that is.
- **Cleanup** in a later release (or by the maintainer), never in the commit that copies: the
  old documents are the rollback.
- **Tests**: the domain function; the repository on `FakeFirebaseFirestore` seeded with old
  documents (idempotency included); `test/firestore/` for both paths during the overlap;
  account deletion erasing both; then a test account on a device.

## 4. Migration run by the maintainer

For what the user's own app can't reach: other users' documents, a shared collection, a field
that must change everywhere before a rule tightens.
- A few documents: by hand in the console, from a written list of changes.
- More: an Admin SDK script (Node or Python) the maintainer runs on their machine with a
  service-account key. Agents may draft it in the scratchpad for review; it enters the repo only
  if approved, and the key never enters the repo, the chat or a log.
- Every script has a dry-run mode that only counts, backs up what it will change first (a JSON
  dump; Firestore's managed export needs the Blaze plan and a bucket), and prints the counts to
  compare after the run.

## 5. Plan A16 — older groups out of the shared collection

Facts (`schema.md` §1, §5): shared `category` documents carry no owner. A user's own old groups
are the ids in `user/{uid}.categories` whose `name` isn't a predefined key (`family`, `friend`,
`colleague`, `other`). Private groups use the same id space, so copying `category/{id}` to
`user/{uid}/categories/{id}` keeps every birthday's `categories` valid.

1. **Prerequisite**: the current rules deployed (`user/{uid}/categories` allowed).
2. **Release N (app, lazy)**: at session start, for each such id not yet private, copy
   `name` and `icon` with `set` under the same id; then `arrayRemove` the copied ids from
   `user.categories`. Both steps are idempotent; `userGroups` already shows an id once, so the
   overlap looks normal. A group several users picked gets one private copy per user.
3. **Console (maintainer)**: add `predefined: true` to the four predefined documents.
4. **Release N+1**, once the maintainer's devices run N: `watchCategories` queries
   `where('predefined', isEqualTo: true)`, and the rules become
   `allow read: if isSignedIn() && resource.data.predefined == true;` — no `create`. The query
   filter is mandatory: rules are not filters. Rules tests: a predefined group readable, another
   one refused, the query without the filter refused, signed-out refused.
5. **Cleanup (maintainer, optional)**: delete the users' old shared documents; they are
   unreadable after N+1 anyway.

Size: M for the app, plus two console steps. Closes A16; `schema.md` §5 and §9 shrink.

## 6. Plan M10 — per-user collections

Only on a concrete need (sharing, rules complexity, cost): `architecture/references/migration.md`
§3.
- `birthday/{id}` → `user/{uid}/birthdays/{id}`, `books/{id}` → `user/{uid}/books/{id}`, same
  ids; owner by path, so the `uid` field and filter go.
- The birth date becomes `day`, `month` and an optional `year`, read from the old timestamp *in
  the device's timezone* — the day the user has been seeing — which ends the timezone shift of
  `date` (`SKILL.md`, gotchas).
- Lazy copy at session start (§3), a profile marker (`migrations: ['m10']`) switching writes to
  the new path, dual read merging by id meanwhile, account deletion erasing both paths.
- Rules: the new paths before release N; `birthday` and `books` closed after N+1; then the
  composite index on `books` can go (a subcollection ordered by `scannedAt` needs only the
  automatic single-field index).

## 7. Brief

```
Migration : <quoi> · Pourquoi maintenant · Données touchées (chemins, volume estimé)
Étapes livrables : versions de l'app, règles, actions console, dans l'ordre
Chevauchement : combien de temps, quels appareils · Retour arrière à chaque étape
Tests : domaine, repository, règles, appareil · Ce que tu fais, et quand
```
