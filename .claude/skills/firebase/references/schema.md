# Data map — every Firestore path AnKi reads or writes

Firestore has no schema: this file is it. It was written from the repositories on 2026-10-25;
update it in the same change as a repository's mapping, a query or `firestore.rules`. Types are
Firestore types; « absent » means older documents may lack the field and the reader must cope.

## Contents
1. `user/{uid}` — profile
2. `user/{uid}/categories/{id}` — private groups
3. `birthday/{id}`
4. `books/{id}`
5. `category/{id}` — shared groups
6. Firebase Auth
7. Queries and indexes
8. Account deletion
9. Shapes still read for old documents
10. Guest move to an existing Google account (B5.5)

---

## 1. `user/{uid}` — profile

Owner: the path (`{uid}` = `request.auth.uid`). Rules: owner reads and writes, nobody else; the marked address deletes a marked profile (§10).

| Field | Type | Meaning, default when absent |
|-------|------|------------------------------|
| `name`, `surname` | string | names shown in the greeting; `''` |
| `pseudo` | string, optional | nickname |
| `categories` | array of string, legacy | shared groups picked before private groups (2026-10-24); ignored since 2026-11-04, never written |
| `themeMode` | string `system` · `light` · `dark` | absent → the legacy `isDark`, else `system` |
| `isDark` | bool, legacy | read only when `themeMode` is absent; deleted by the next theme change |
| `locale` | string `fr` · `en`, optional | language picked in Settings; absent → the phone's (first translated one of its preferred languages, else English). Not written at creation since 2026-11-08; older profiles keep the `'fr'` they were created with |
| `biometricToken` | string or null | set by the auth feature when the fingerprint lock is on; null or absent = off |
| `reminders` | map `{leads: [string], hour: int, minute: int}`, optional | default reminder setting (B6); absent → J-7 + J-0 at 10:00; unknown leads skipped, `sameDay` always added; written only by `ReminderPreferencesRepository.savePreferences` (`update`) |
| `transferTo` | string, optional | a guest moving to a Google account (§10): that account's address; the marked document is deleted by it |

- Written by `UserRepository.markForTransfer` (§10), `UserRepository.createUser` (transaction: creates only if absent, never overwrites),
  `updatePreferences` (`update`: `pseudo`, `themeMode` + delete `isDark`, `locale`), `updateNames`
  (`update`), `deleteUser`; `AuthRepository.setBiometricToken` (`set` with `merge`).
- Read by `UserRepository.watchUser` (stream; null while the document doesn't exist) and
  `AuthRepository.isBiometricTokenValid` (`get`), `ReminderPreferencesRepository.watchPreferences`
  (the `reminders` field of the profile document).

## 2. `user/{uid}/categories/{id}` — private groups

Groups a user creates since 2026-10-24, plus the older ones copied from `category` on
2026-11-04 (§5). Owner: the path. Rules: owner reads and writes.

| Field | Type | Meaning |
|-------|------|---------|
| `name` | string | typed by the user |
| `icon` | int | Material icon code point; absent → `0xe148` (`Icons.category`) |
| `tone` | int, optional | index of the tone seed (`LabelTones`); absent on groups older than 2026-10-24 |
| `transferTo` | string, optional | guest move (§10): deleted by the marked address once copied |

- Ids come from `CategoryRepository.newCategoryId()`, generated on the shared `category`
  collection reference, so a private id never collides with a shared one and birthdays can
  point at either.
- Written by `createCategory` (`set` on that id), `updateCategory` (name, icon, tone; 43aa09e),
  `deleteCategory` (deletes the group and removes it from its birthdays' `categories` in the same
  `writeInBatches`, 3a6c87d; beyond one batch it is no longer atomic), `markForTransfer` and
  `takeOver` (§10); erased by `deleteAllUserCategories`. Read by `watchOwnCategories` (the whole
  subcollection, stream) and `fetchOwnCategories` (server read).

## 3. `birthday/{id}`

Owner: the `uid` field. Rules: read and delete by the owner; create only with one's own `uid`;
update by the owner without changing `uid`; the marked address deletes or takes over a marked document (§10).

| Field | Type | Meaning, default when absent |
|-------|------|------------------------------|
| `uid` | string | owner; on every document, written on create and update |
| `name`, `surname` | string | trimmed; `surname` may be `''` |
| `date` | timestamp | local midnight of the birth date; year 2000 when unknown; **a document without it is skipped** |
| `yearKnown` | bool | absent → `true`; `false` → ignore the year in `date` |
| `categories` | array of string | group ids, shared or private; `[]` |
| `picture` | string, optional | base64 JPEG (picked at 512 px, quality 80); undecodable → no photo |
| `wishedYears` | array of int | years the birthday was wished; `[]`; non-int values ignored |
| `reminders` | array of string, optional | the person's own leads (`monthBefore`, `weekBefore`, `dayBefore`, `sameDay`): absent → the default setting, `[]` → no reminder; written alone by `updateReminders` (person page), erased with `FieldValue.delete()` when back to the default |
| `wishMessage` | string, optional | the person's own wish message (≤ 500 characters, trimmed), shared by « Souhaiter » on the day and the day after: absent or blank → the default message; written alone by `updateWishMessage` (person page), erased with `FieldValue.delete()` when back to the default |
| `transferTo` | string, optional | guest move (§10): the marked address takes the document (`uid` its own, mark removed) or deletes it |

- Written by `BirthdayRepository.createBirthday` (`set` on an id drawn client-side by
  `newBirthdayId`, so the app can open the new person's page offline), `createBirthdays`
  (contacts import, batches of ≤ 500), `updateBirthday` (`update` of every draft field plus
  `uid`; `picture` only when a new one is given; never `reminders` nor `wishMessage`), `updateReminders`
  (`update` of `reminders` only), `updateWishMessage` (`update` of `wishMessage` only), `markWished` / `unmarkWished` (`update` with `arrayUnion` /
  `arrayRemove`), `deleteBirthday`, `deleteAllUserBirthdays`, `markForTransfer` and `takeOver`
  (§10).
- Read by `watchBirthdays`: `where('uid', isEqualTo: uid)`, stream; `fetchBirthdays` (same filter).

## 4. `books/{id}`

Owner: the `uid` field. Rules: same as `birthday`; the marked address deletes or takes over a marked document (§10).

| Field | Type | Meaning |
|-------|------|---------|
| `uid` | string | owner |
| `title` | string | from Google Books |
| `authors` | array of string | |
| `isbn` | string | as scanned |
| `imageUrl`, `publishedDate`, `description` | string, optional | from Google Books (`publishedDate` is its free-form string) |
| `pageCount` | int, optional | |
| `scannedAt` | timestamp | the app's clock at saving; the list's order |
| `transferTo` | string, optional | guest move (§10), as on `birthday` |

- Written by `BookRepository.saveBook` (`add`), `markForTransfer` and `takeOver` (§10); erased by
  `deleteAllUserBooks`.
- Read by `watchBooks`: `where('uid', isEqualTo: uid).orderBy('scannedAt', descending: true)` —
  composite index (§7).

## 5. `category/{id}` — shared groups

The four predefined groups, created by hand in the console and flagged `predefined: true`. Rules:
a signed-in user reads documents with `predefined == true`; nobody creates, updates or deletes.
Older users' groups (app versions before 2026-10-24) were copied by the maintainer under
`user/{uid}/categories` on 2026-11-04 (`console.md` §10) and are no longer readable here.

| Field | Type | Meaning |
|-------|------|---------|
| `name` | string | a key the UI translates (`family`, `friend`, `colleague`, `other`) |
| `predefined` | bool | `true`; required by the rules and the query (added in the console, `console.md` §10) |
| `icon` | int | Material code point |
| `tone` | int, optional | absent on these documents |

- Read by `CategoryRepository.watchCategories`: `where('predefined', isEqualTo: true)`, mandatory
  (rules are not filters). The app never writes here.

## 6. Firebase Auth

- Providers: Google (needs each signing key's SHA-1, console runbook §4), e-mail/password (reset
  link in the app's language: `setLanguageCode` before `sendPasswordResetEmail`, templates in the
  console), anonymous (« invité »).
- Linking a guest to Google keeps the uid, so every document stays its own. A Google account
  that already has data takes the guest's documents over instead (§10).
- E-mail enumeration protection is on: a wrong e-mail or password answers
  `invalid-credential` (`AuthFailure.invalidCredentials`); a reset to an unknown address
  « succeeds » silently.
- Deleting the Auth account deletes no document and fails with `requires-recent-login` on an
  old sign-in, so the app confirms the identity first (§8); a guest cannot, and is signed out
  after its data is erased.

## 7. Queries and indexes

| Query | Index | Where |
|-------|-------|-------|
| `birthday` where `uid ==` | automatic single-field | — |
| `books` where `uid ==`, order by `scannedAt` desc | composite `uid` ASC, `scannedAt` DESC | `firestore.indexes.json` (deployed) |
| `category` where `predefined ==` | automatic single-field | — |
| `user/{uid}/categories` (all) | none | — |

`firestore.indexes.json` also carries a field override on `user.name` that exists in production
(its default indexes, listed explicitly); keep it so a deploy doesn't offer to remove it. The
emulator serves every query without indexes: a missing one surfaces only against production, as
`FAILED_PRECONDITION` with a console link in logcat.

## 8. Account deletion

`AccountDeletion.deleteAccount()` (settings feature) runs `AuthController.confirmIdentity()`
(Google picker, the password typed in the dialog, nothing for a guest), then `_eraseData(uid)`,
then `AuthController.deleteAccount()`; nothing is erased unless the identity is confirmed.
`_eraseData` runs every module's eraser (`userDataErasersProvider`, a `core` provider that `app/`
overrides from the module registry, `app/modules/module_data_hooks.dart`; it throws without the
override), in registry order, then deletes the profile. Every registered module counts, active or
not: a disabled module keeps its data, which still leaves with the account (decision D13). The
first eraser that fails stops the run, and the profile and the account stay.

| Order | Module | Erases | How |
|-------|--------|--------|-----|
| 1 | Anniversaires (`birthdaysModule.data`) | `birthday` where `uid ==` | query, then batches of deletes |
| 2 | Anniversaires | `user/{uid}/categories` | query, then batches (a subcollection survives its parent) |
| 3 | Livres (`booksModule.data`) | `books` where `uid ==` | query, then batches of deletes |
| 4 | — | `user/{uid}` | delete |
| 5 | — | the Auth account | after the data, identity confirmed first (a guest that gets `requires-recent-login` is signed out) |

Rules of the run:
- The deletion queries read the server (`Source.server`): offline nothing starts, else a partial
  cache would leave documents (a66f754).
- `AppInitializer` doesn't recreate the profile during `AccountDeletion`, and recreates it if the
  Auth deletion fails (`app/bootstrap/app_initializer.dart`; a66f754).
- After `deleteCurrentUser` nothing is written to the profile (the session is gone, the rules
  refuse); only the device's biometric token is cleared (a660627).
- What survives: the older non-predefined `category/{id}` documents (`console.md` §10, last
  step, not done) and, after a takeover, the guest's empty anonymous Auth user.

Invariant: every per-user path in this file appears in this table. A new collection adds its
`deleteAllUser…` method, a call in its module's eraser (`ModuleData.eraser`, in
`app/modules/<module>_module.dart`) and a test (`test/app/modules/module_data_hooks_test.dart`).

## 9. Shapes still read for old documents

Delete a line only when no such document can remain (migrated, or the field rewritten
everywhere):
- `birthday` without `yearKnown` (year known), `wishedYears` (never wished), `reminders` (default setting) or `wishMessage` (default message).
- `user` without `reminders` (default setting).
- `user` with `isDark` instead of `themeMode`.
- `user.categories` (shared groups picked before): no longer read nor written since 2026-11-04;
  older profiles keep it, ignored, until the account is deleted.
- `category` without `tone`; any group without `icon`.
- `birthday` without `date`: skipped, not shown.
- A contact imported before 2026-10-12 without a year: `date` in 2000 without `yearKnown`, so read
  as born in 2000; only the birthday form fixes it (99771e2).

## 10. Guest move to an existing Google account (B5.5)

A guest whose Google account already has AnKi data opens that account with its birthdays
(`GuestMerge`, `lib/features/settings/providers/guest_merge.dart`, d99cce9). Signing in replaces the anonymous session, so a plain copy
would leave the guest's documents orphaned under a uid nobody opens again. They move instead:

1. As the guest, online (server reads, marks awaited until the server acknowledges them, within
   20 s for all of them: `markTimeout`, else `GuestMergeFailure.offline`):
   `markForTransfer` writes `transferTo` = the chosen Google address (an owner's ordinary
   update), in this order: `birthday`, `user/{uid}/categories`, then each other module's
   transfer, then `user/{uid}`. `GuestMerge` marks the birthdays and groups itself (their
   duplicate plan); the other modules go through `guestDataTransfersProvider`, a `core` provider
   that `app/` overrides from the module registry (`app/modules/module_data_hooks.dart`), every
   registered module, active or not: Livres marks `books` and returns its takeover by ids.
2. Sign-in with that Google account (`AuthController.openGoogleAccount`).
3. As the target, by the ids kept in memory (no query on someone else's data): `takeOver`
   gives each guest birthday to the target (`uid`, remapped `categories`, `transferTo`
   removed), or deletes a birthday the target already has (the import's matching rule: folded
   name, day and month); guest groups are recreated under `user/{target}/categories` with their
   ids, or mapped to a target group of the same folded name, and deleted under
   `user/{guest}/categories` (before the birthdays move); then each module's takeover runs
   (Livres: `books` get the target `uid`, without the mark), and the guest profile is deleted.
   A takeover that fails leaves `GuestMergeFailure.incomplete` and the guest profile in place.

Rules (`rules.md` §1): the marked address may delete a marked document, and update a marked
`birthday` or `books` document only to make it its own without the mark; it never reads them.
What stays: the empty anonymous Auth user; a move cut between steps 2 and 3 (app killed) leaves
marked documents nobody claims; an unverified address (marks set, takeover refused:
`GuestMergeFailure.incomplete`) leaves the documents marked; on a duplicate, the guest's photo,
`wishedYears`, own reminders and own wish message are lost (ux D29, open).
