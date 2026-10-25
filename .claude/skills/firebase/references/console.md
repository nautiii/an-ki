# Console runbooks — what the maintainer runs

Production is `an-ki-9b02b`. Agents prepare (tests, compilation, exact commands, what to check)
and hand over; the maintainer runs what follows (`guard-git.sh` blocks it for agents). When
handing over, quote the runbook's commands with the project id and say what to check after.

## Contents
1. Deploy the rules
2. Deploy the indexes
3. See what production runs
4. Register a signing key (Google Sign-In)
5. Regenerate the Firebase config (flutterfire)
6. Sign-in providers and e-mails
7. API keys and App Check
8. Usage, quotas, budget
9. Production data and test accounts

---

## 1. Deploy the rules

When: `firestore.rules` changed. Pending on 2026-10-25: private groups and the pinned owner
(`architecture/references/migration.md` §1).

```powershell
.\scripts\test_firestore_rules.ps1
firebase deploy --only firestore:rules --dry-run --non-interactive --project an-ki-9b02b
firebase deploy --only firestore:rules --project an-ki-9b02b
```

- The first two must end green (« All tests passed », « compiled successfully »).
- After: the console's Rules tab shows the new version with today's date. New requests use it
  within about a minute, listeners already open within ten. Then check on a device the flows
  that waited for it (`migration.md` §1) and delete their lines.
- Rollback: the Rules tab's history restores a previous version in one click; or deploy an
  older file (`git show <commit>:firestore.rules`).

## 2. Deploy the indexes

When: `firestore.indexes.json` changed.

```powershell
firebase deploy --only firestore:indexes --project an-ki-9b02b
```

- A new composite index builds in minutes (console, Indexes tab: « Building » → « Enabled »);
  the query fails with `FAILED_PRECONDITION` until then.
- The CLI asks before deleting an index present in production but missing from the file:
  answer no unless that is the point — then export again (§3).
- An index created from a console link (the error's URL) lives only in production: export it
  into the file the same day.

## 3. See what production runs

- Indexes (agents may run it, read-only):
  `firebase firestore:indexes --project an-ki-9b02b > firestore.indexes.json`, then `git diff`.
- Rules: the console's Rules tab shows the deployed source and its history; compare with
  `git log -1 --format=%cd -- firestore.rules`. Its Rules playground simulates a request against
  the deployed rules.

## 4. Register a signing key (Google Sign-In)

When: a new PC's debug keystore, the future release key, or Google sign-in failing at once with
a configuration error. Pending on 2026-10-25 for the current PC's debug key
(`migration.md` §1, guest backup).

```powershell
keytool -list -v -keystore "$HOME\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

(`keytool` comes with any JDK, e.g. in `~/.jdks`; or `cd android; .\gradlew signingReport` in the
Terminal panel.) Console → Project settings → Your apps → Android `com.github.nautiii.an_ki` →
Add fingerprint: the SHA-1, and the SHA-256. If the console offers a new `google-services.json`,
replace `android/app/google-services.json` and commit it on its own
(`CHORE(firebase): register <machine> debug key`). Check: Google sign-in on the device.

## 5. Regenerate the Firebase config (flutterfire)

When: a platform or an app added or removed. Pending: `firebase.json` and
`lib/core/firebase_options.dart` still describe the web app removed on 2026-10-12.

In the Terminal panel (`pub global` writes to the pub cache, sandboxed in Claude's shells):

```powershell
dart pub global activate flutterfire_cli
flutterfire configure --project=an-ki-9b02b --platforms=android,ios --out=lib/core/firebase_options.dart
```

(`flutterfire configure --help` if a flag moved.) Then review the diff: `firebase.json` keeps its
`firestore` and `emulators` sections, `lib/core/firebase_options.dart` loses `web`,
`google-services.json` stays as it was unless the console changed. `flutter analyze`, a run on a
device, then one commit (`CHORE(firebase): drop the web app config`).

## 6. Sign-in providers and e-mails

Console → Authentication:
- Providers: Google, Email/Password and Anonymous enabled.
- Settings: e-mail enumeration protection on (the app expects `invalid-credential`).
- Templates → password reset: French and English versions (the app sets the language before
  sending), sender name « AnKi ».
- Accounts: test accounts are created and deleted through the app, so account deletion gets
  exercised too (debt A17).

## 7. API keys and App Check

- The Android API key in `google-services.json` is public by design; what protects data is the
  rules. Restricting it (Google Cloud → APIs & Services → Credentials: Android apps with the
  package and every registered SHA-1) limits abuse of quotas; test sign-in and sync on a device
  right after, since a wrong restriction breaks the app without a clear error.
- The Google Books key (`secrets.json`) gets the same Android restriction, plus the Books API
  only.
- App Check (Play Integrity) would refuse requests from anything but the genuine app. It needs
  the `firebase_app_check` plugin: a system change, brief first; enforce only after watching its
  metrics for a while.

## 8. Usage, quotas, budget

Console → Usage and billing. On the free Spark plan Firestore allows 50,000 reads, 20,000 writes
and 20,000 deletes a day and 1 GiB stored; beyond that requests fail until the next day. On
Blaze, set a budget alert in Google Cloud Billing. The shared `category` stream reads every
shared document for every user at each session (debt A16): watch it as users grow.

## 9. Production data and test accounts

Console → Firestore → Data is for looking. Editing a user's document by hand is a migration
(`migrations.md` §4): written list first, then the change, then a check. Experiments happen on
the emulator (`demo-anki`) or on a test account, never on the maintainer's own data.
