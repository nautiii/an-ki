# Firebase backlog — what remains

Started on 2026-10-25, when the skill and the emulator tests landed. Verify an item still holds
before acting (the console changes outside git); delete it once done, add what you find (one
line: what, evidence, who, runbook). « Mainteneur » items are console or production steps
agents only prepare.

| # | Item | Why | Who | How |
|---|------|-----|-----|-----|
| F2 | Register the current PC's debug SHA-1 (and SHA-256) | Google sign-in and guest backup fail on this machine's builds | mainteneur | `console.md` §4 |
| F3 | Drop the web app from the Firebase config | `firebase.json` and `lib/core/firebase_options.dart` still describe the web app removed on 2026-10-12 | mainteneur, agent reviews the diff | `console.md` §5 |
| F6 | Restrict the Android API key and confirm the Google Books key's restrictions | quota abuse; the Books key leaked publicly in October and had to be rotated and restricted | mainteneur | `console.md` §7, then sign-in, sync and a scan on a device |
| F7 | Check the plan and set a budget alert if on Blaze | nothing tells us today when quotas or costs move | mainteneur | `console.md` §8 |
| F8 | Decide on App Check (Play Integrity) | only the rules stop a modified client today | agent brief, mainteneur decides | system change: new plugin `firebase_app_check` |
| F9 | `scripts/*.ps1` show garbled accents in Windows PowerShell 5.1 | the scripts are UTF-8 without BOM, which 5.1 reads as ANSI (seen with `test_firestore_rules.ps1`'s messages); PowerShell 7 is fine | agent, on approval | a BOM for `*.ps1` (`.editorconfig` `charset = utf-8-bom`), or messages without accents |
| F11 | Delete the older non-predefined `category/{id}` documents (last step of `console.md` §10, optional, not done) | until then they survive account deletion | maintainer | `console.md` §10 |
