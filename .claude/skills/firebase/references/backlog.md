# Firebase backlog — what remains

Started on 2026-10-25, when the skill and the emulator tests landed. Verify an item still holds
before acting (the console changes outside git); delete it once done, add what you find (one
line: what, evidence, who, runbook). « Mainteneur » items are console or production steps
agents only prepare.

| # | Item | Why | Who | How |
|---|------|-----|-----|-----|
| F1 | Deploy `firestore.rules` | git is ahead of production: private groups refused by the server (a new group vanishes), owner not pinned on update; tests and server compilation green on 2026-10-25 | mainteneur | `console.md` §1, then the device checks of `architecture/references/migration.md` §1 |
| F2 | Register the current PC's debug SHA-1 (and SHA-256) | Google sign-in and guest backup fail on this machine's builds | mainteneur | `console.md` §4 |
| F3 | Drop the web app from the Firebase config | `firebase.json` and `lib/core/firebase_options.dart` still describe the web app removed on 2026-10-12 | mainteneur, agent reviews the diff | `console.md` §5 |
| F4 | A16 — older groups out of `category`, then remove its `create` permission | any signed-in account reads every user's old group names and may still create shared groups the app no longer writes; `test/firestore` documents that `create` | agent (app, rules, tests) + mainteneur (console, deploys) | `migrations.md` §5 — system change: brief first |
| F5 | A17 — account deletion order | data erased, then Auth refuses with `requires-recent-login`: the account survives empty | agent, with the architecture skill | brief: re-authenticate first, or delete the account before its data |
| F6 | Restrict the Android API key and confirm the Google Books key's restrictions | quota abuse; the Books key leaked publicly in October and had to be rotated and restricted | mainteneur | `console.md` §7, then sign-in, sync and a scan on a device |
| F7 | Check the plan and set a budget alert if on Blaze | nothing tells us today when quotas or costs move | mainteneur | `console.md` §8 |
| F8 | Decide on App Check (Play Integrity) | only the rules stop a modified client today | agent brief, mainteneur decides | system change: new plugin `firebase_app_check` |
| F9 | `scripts/*.ps1` show garbled accents in Windows PowerShell 5.1 | the scripts are UTF-8 without BOM, which 5.1 reads as ANSI (seen with `test_firestore_rules.ps1`'s messages); PowerShell 7 is fine | agent, on approval | a BOM for `*.ps1` (`.editorconfig` `charset = utf-8-bom`), or messages without accents |
| F10 | Decide whether to track `.firebaserc` | an untracked alias file (`anki` → `an-ki-9b02b`); every command in the skill passes `--project` anyway | mainteneur | commit it, or add it to `.gitignore` |
