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

---

## 1. `user/{uid}` — profile

Owner: the path (`{uid}` = `request.auth.uid`). Rules: owner reads and writes, nobody else.

| Field | Type | Meaning, default when absent |
|-------|------|------------------------------|
| `name`, `surname` | string | names shown in the greeting; `''` |
| `pseudo` | string, optional | nickname |
| `categories` | array of string | ids of shared `category` documents picked before private groups (2026-10-24); `[]` |
| `themeMode` | string `system` · `light` · `dark` | absent → the legacy `isDark`, else `system` |
| `isDark` | bool, legacy | read only when `themeMode` is absent; deleted by the next theme change |
| `locale` | string | `'fr'` |
| `biometricToken` | string or null | set by the auth feature when the fingerprint lock is on; null or absent = off |
| `reminders` | map `{leads: [string], hour: int, minute: int}`, optional | default reminder setting (B6); absent → J-7 + J-0 at 10:00; unknown leads skipped, `sameDay` always added; written only by `ReminderPreferencesRepository.savePreferences` (`update`) |

- Written by `UserRepository.createUser` (transaction: creates only if absent, never overwrites),
  `updatePreferences` (`update`: `pseudo`, `themeMode` + delete `isDark`, `locale`), `updateNames`
  (`update`), `deleteUser`; `AuthRepository.setBiometricToken` (`set` with `merge`).
- Read by `UserRepository.watchUser` (stream; null while the document doesn't exist) and
  `AuthRepository.isBiometricTokenValid` (`get`).

## 2. `user/{uid}/categories/{id}` — private groups

Groups a user creates since 2026-10-24. Owner: the path. Rules: owner reads and writes.

| Field | Type | Meaning |
|-------|------|---------|
| `name` | string | typed by the user |
| `icon` | int | Material icon code point; absent → `0xe148` (`Icons.category`) |
| `tone` | int, optional | index of the tone seed (`LabelTones`) |

- Ids come from `CategoryRepository.newCategoryId()`, generated on the shared `category`
  collection reference, so a private id never collides with a shared one and birthdays can
  point at either.
- Written by `createCategory` (`set` on that id); erased by `deleteAllUserCategories`. No
  update path yet. Read by `watchOwnCategories` (the whole subcollection, stream).

## 3. `birthday/{id}`

Owner: the `uid` field. Rules: read and delete by the owner; create only with one's own `uid`;
update by the owner without changing `uid`.

| Field | Type | Meaning, default when absent |
|-------|------|------------------------------|
| `uid` | string | owner; on every document, written on create and update |
| `name`, `surname` | string | trimmed; `surname` may be `''` |
| `date` | timestamp | local midnight of the birth date; year 2000 when unknown; **a document without it is skipped** |
| `yearKnown` | bool | absent → `true`; `false` → ignore the year in `date` |
| `categories` | array of string | group ids, shared or private; `[]` |
| `picture` | string, optional | base64 JPEG (picked at 512 px, quality 80); undecodable → no photo |
| `wishedYears` | array of int | years the birthday was wished; `[]`; non-int values ignored |
| `reminders` | array of string, optional | the person's own leads (`monthBefore`, `weekBefore`, `dayBefore`, `sameDay`): absent → the default setting, `[]` → no reminder; erased by `updateBirthday` when back to the default |

- Written by `BirthdayRepository.createBirthday` (`add`), `createBirthdays` (contacts import,
  batches of ≤ 500), `updateBirthday` (`update` of every draft field plus `uid`; `picture` only
  when a new one is given), `markWished` / `unmarkWished` (`update` with `arrayUnion` /
  `arrayRemove`), `deleteBirthday`, `deleteAllUserBirthdays`.
- Read by `watchBirthdays`: `where('uid', isEqualTo: uid)`, stream.

## 4. `books/{id}`

Owner: the `uid` field. Rules: same as `birthday`.

| Field | Type | Meaning |
|-------|------|---------|
| `uid` | string | owner |
| `title` | string | from Google Books |
| `authors` | array of string | |
| `isbn` | string | as scanned |
| `imageUrl`, `publishedDate`, `description` | string, optional | from Google Books (`publishedDate` is its free-form string) |
| `pageCount` | int, optional | |
| `scannedAt` | timestamp | the app's clock at saving; the list's order |

- Written by `BookRepository.saveBook` (`add`); erased by `deleteAllUserBooks`.
- Read by `watchBooks`: `where('uid', isEqualTo: uid).orderBy('scannedAt', descending: true)` —
  composite index (§7).

## 5. `category/{id}` — shared groups

Read by every signed-in user; created by hand in the console (predefined) or by app versions
before 2026-10-24 (users' groups). Rules today: any signed-in user reads and **creates**, nobody
updates or deletes.

| Field | Type | Meaning |
|-------|------|---------|
| `name` | string | predefined: a key the UI translates (`family`, `friend`, `colleague`, `other`); older users' groups: the typed name |
| `icon` | int | Material code point |
| `tone` | int, optional | absent on these documents |

- Read by `CategoryRepository.watchCategories`: the whole collection, by every user — every
  user's old groups included (debt A16: names visible to any account, reads growing with the
  user base). The app no longer writes here; the `create` permission only serves old app
  versions and should go once A16 is done (`migrations.md`).

## 6. Firebase Auth

- Providers: Google (needs each signing key's SHA-1, console runbook §4), e-mail/password (reset
  link in the app's language: `setLanguageCode` before `sendPasswordResetEmail`, templates in the
  console), anonymous (« invité »).
- Linking a guest to Google keeps the uid, so every document stays its own.
- E-mail enumeration protection is on: a wrong e-mail or password answers
  `invalid-credential` (`AuthFailure.invalidCredentials`); a reset to an unknown address
  « succeeds » silently.
- Deleting the Auth account deletes no document and fails with `requires-recent-login` on an
  old sign-in (debt A17).

## 7. Queries and indexes

| Query | Index | Where |
|-------|-------|-------|
| `birthday` where `uid ==` | automatic single-field | — |
| `books` where `uid ==`, order by `scannedAt` desc | composite `uid` ASC, `scannedAt` DESC | `firestore.indexes.json` (deployed) |
| `category` (all) | none | — |
| `user/{uid}/categories` (all) | none | — |

`firestore.indexes.json` also carries a field override on `user.name` that exists in production
(its default indexes, listed explicitly); keep it so a deploy doesn't offer to remove it. The
emulator serves every query without indexes: a missing one surfaces only against production, as
`FAILED_PRECONDITION` with a console link in logcat.

## 8. Account deletion

`AccountDeletion.eraseData()` (settings feature), then `AuthController.deleteAccount()`:

| Order | Erases | How |
|-------|--------|-----|
| 1 | `birthday` where `uid ==` | query, then batches of deletes |
| 2 | `books` where `uid ==` | query, then batches of deletes |
| 3 | `user/{uid}/categories` | query, then batches (a subcollection survives its parent) |
| 4 | `user/{uid}` | delete |
| 5 | the Auth account | after the data (debt A17: it may refuse) |

Invariant: every per-user path in this file appears in this table. A new collection adds its
`deleteAllUser…` method, a line in `eraseData()` and a test.

## 9. Shapes still read for old documents

Delete a line only when no such document can remain (migrated, or the field rewritten
everywhere):
- `birthday` without `yearKnown` (year known), `wishedYears` (never wished) or `reminders` (default setting).
- `user` without `reminders` (default setting).
- `user` with `isDark` instead of `themeMode`.
- `user.categories` and users' own groups in the shared `category` collection (A16).
- `category` without `tone`; any group without `icon`.
- `birthday` without `date`: skipped, not shown.
