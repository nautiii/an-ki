# AnKi — agent guide

AnKi (暗記, *learn by heart*; repo **kairos**, *the right moment*) is a Flutter app that makes sure
you never miss the birthday of someone you care about. Three user jobs, by frequency:
**see who's next** (daily, in under 2 s), **act on it** (wish, find a gift), **capture** (add or
import a birthday in under 10 s). Data syncs through Firebase and works offline; reminders are
scheduled on the device so they fire without network. Android first: the maintainer tests on a
physical phone over USB, agents on the `Honor_Magic7_Pro` emulator (device skill). iOS must stay
correct but hasn't been built on the current setup.

## Working agreement

- Talk to the maintainer in **French**. Identifiers, file names, commit messages and PR titles in
  **English**. Explanatory code comments (`//`, `///`) in **French**.
- Size the change, it sets the ceremony:
  - **local** (a field, a widget, a fix inside existing layers) → do it, tests included;
  - **structural** (new feature, edge between features, model or Firestore shape, screen
    redesign) → short brief in French, build after a go;
  - **system** (new package, plugin or permission, navigation or state library, data migration,
    theme or identity, anything contradicting an architecture decision) → brief and explicit
    approval.
- The current code and UI are a draft, not a constraint: when the structure is the problem,
  propose the better structure instead of patching around it.
- Fix what's broken in the code you touch; report unrelated problems (failing tests included)
  instead of fixing them silently.
- Show, don't claim: say what you ran (format, analyze, tests, device) and what you didn't.

## Delegation (Claude Code, `.claude/agents/`)

The main session keeps every judgement (design, briefs, decisions) and delegates the rest with a
complete brief: mechanical changes → `implementer`, emulator or phone checks → `device-runner`.
It runs the checks itself, without an agent: `bash .claude/hooks/verify-index.sh` (Bash in the
background; prints only failures), always at the end of a session that changed code or tooling,
and whenever there is a real need: before each commit, or to settle a doubt mid-task, never
after every edit.
Every logical change, side sessions included: implement → stage it whole (explicit paths) →
checks + `reviewer` in parallel, the reviewer's model given by `bash .claude/hooks/review-model.sh`
(a structural or system change: Opus) → apply the findings, re-stage, checks again → commit, in
one or several atomic commits, the checks passing on each index (one review per change, none for
markdown). `guard-git.sh` blocks the commit otherwise (git-workflow skill).
A change visible in the app goes through `device-runner` before the final report, or the report
says « appareil : non vérifié » and why.

## Stack

Flutter 3.47.9 · Dart 3.13.7 · Material 3 · Riverpod 3.4 (hand-written providers, no codegen) ·
go_router 17 (pinned, decision D9) · Firebase Auth (Google through google_sign_in, email,
anonymous) and Cloud Firestore (offline persistence on, no Storage) · flutter_local_notifications
with timezone, replanned daily by workmanager · local_auth with flutter_secure_storage (fingerprint
lock) · mobile_scanner (ISBN) · flutter_contacts (import) · image_picker (photos) · share_plus
(system share sheet) · gen-l10n (French template, English).
Every dependency is pinned to an exact version.

## Commands

| Task | Command |
|------|---------|
| Dependencies | `flutter pub get` |
| Format | `dart format <files>` |
| Analysis — must be clean | `dart analyze --fatal-infos` (what `flutter analyze` reports, plus the `riverpod_lint` plugin) |
| Tests | `flutter test`, or `flutter test test/features/<feature>` |
| All checks (Claude Code): project norms, l10n, format, analysis, tests; on a staged index, records the commit verdict | `bash .claude/hooks/verify-index.sh [static\|tests]` |
| Firestore rules, in the emulator (Firebase CLI, Java 21+) | `scripts/test_firestore_rules.ps1` (firebase skill) |
| Strings, after any `.arb` change | `flutter gen-l10n` |
| Run on a device | `scripts/run.ps1 [-Example] [-d <device id>]` (`secrets.json`, or `secrets.example.json` with `-Example`; agents: device skill) |
| Build and install an APK | `scripts/build_and_deploy.ps1 [-Release] [-Clean]` |
| Icon / splash, after changing their pubspec config | `dart run flutter_launcher_icons` · `dart run flutter_native_splash:create` |

The app reads `GOOGLE_BOOKS_API_KEY` from `secrets.json` through `--dart-define-from-file`.
Claude Code hooks (`.claude/hooks/`) format edited `.dart` files and guard git and Firebase
commands (git-workflow, firebase skills); other agents follow the same rules by hand.

## Code map

```
lib/main.dart       process start: Firebase, notifications, ProviderScope
lib/app/            composition root — MaterialApp, route table, shell (tabs), bootstrap; the only code that knows every feature
lib/core/           feature-agnostic — common/ (dumb shared widgets), theme/, services/ (plugin wrappers),
                    providers/, routing/ (route paths), extensions/, config/, constants/;
                    never imports app/ or a feature
lib/features/<f>/   auth · user · birthday · books · reminders · settings — domain/, data/, providers/, screens/, widgets/
lib/l10n/           intl_fr.arb (template) + intl_en.arb; app_localizations*.dart are generated
test/               mirrors lib/; test/support/ holds the widget harness and shared fakes
scripts/            PowerShell: run, build and deploy
```

## Architecture

Feature-first layered MVVM: `screens/ widgets/ → providers/ → data/ → domain/` inside each
feature, features linked by a declared acyclic graph. `test/architecture/architecture_test.dart`
enforces it and lists no known violation; what still differs (open debt, per-user collections)
is in `.claude/skills/architecture/references/migration.md`.

- Banned, and gone from the code: session handling with `startListening`/`clear()`, `XState`
  with `isLoading`/`errorMessage` strings, `AppLocalizations` in notifiers, `.instance`
  singletons read outside a provider or a plugin wrapper, `FirebaseFirestore.instance` defaults
  in repositories, raw route strings, `DateTime.now()` outside `clockProvider`, models importing
  Firestore or Flutter UI (`flutter/foundation.dart` is allowed).
- A bug fix stays a bug fix: restructuring is its own change, one step per commit, behaviour
  locked by tests first.

## House rules — every task

- Absolute imports only: `package:an_ki/...`.
- No hardcoded user-facing string (ARB, French template + English) or color (theme only); dates
  through `intl` `DateFormat` with the locale.
- Widgets render state and forward intents; logic lives in providers and pure domain functions;
  no Firebase or repository call from a widget.
- Riverpod 3 only: never `StateNotifier` or `legacy.dart`; after any `await` in a notifier, check
  `ref.mounted` before touching `state`.
- No code generation (freezed, json_serializable, riverpod_generator, build_runner). Models are
  immutable: `final` fields, `const` constructor, `==`/`hashCode`; a `copyWith` only where code
  copies the object, never by default.
- Strong typing: no `dynamic` in app code (analyzer strict modes are on); `const` wherever
  possible; past ~300 lines, split a widget into private widget classes.
- Every Firestore read and write is scoped to the signed-in user (path or `uid` filter), except
  the shared `category` collection and a guest's documents marked for the Google account taking
  them over (`transferTo`, firebase skill `references/schema.md` §10); multi-document writes go
  through `writeInBatches`.
- Ask before adding a package, a plugin, an Android permission or a data migration; pin exact
  versions (no `^`).
- Every change ships with tests at each layer it touches; aim for meaningful coverage close to
  100 %.
- Never read, print or commit secrets: `secrets.json`, `key.properties`, `*.jks`, `*.keystore`,
  `.env`. `android/app/google-services.json` is tracked on purpose (client config).

## Where to look

- Skills: `.claude/skills/<name>/SKILL.md` (other agents open the one the task needs).
  `/deps-upgrade` and `/dead-code` are started by the maintainer only; asked for an upgrade or a
  cleanup, suggest them.
- Rules of the zone you edit (UI, state, data, navigation, reminders, tests, l10n, platform):
  `.claude/rules/*.md`, loaded by Claude Code; other agents read the matching file.
- Why the architecture is what it is: `.claude/skills/architecture/references/decisions.md`.
- What to do next: `.claude/skills/ux-ui/references/ux-backlog.md` (product, UX) ·
  `.claude/skills/architecture/references/migration.md` (code).

## Glossary

- **Birthday** — a person (name, possibly empty surname, birth date whose year is optional),
  category ids, optional photo stored as base64 in the document, the years it was wished
  (`wishedYears`). Firestore `birthday/{id}`, owned through its `uid` field; an unknown year is
  stored as 2000 with `yearKnown: false`.
- **Category** (« groupe » in the UI) — a name, an icon, an optional tone. The four offered to
  everyone (Famille, Amis, Travail, Autres) live in the shared `category` collection and are
  locked; groups a user creates are private, in `user/{uid}/categories`. The « Groupes » page
  (Settings › Anniversaires) renames, recolours or deletes a private group; its birthdays lose a
  deleted one.
- **User** — the profile document `user/{uid}`: name, surname, pseudo, theme (`themeMode`:
  system, light or dark), locale (absent: the phone's language, else English), biometric token.
- **Reminder** — local notifications on the day (J-0) and, by default, 7 days before (J-7), at
  10:00 device time; Settings › Anniversaires picks J-30, J-7, J-1 and the time
  (`user/{uid}.reminders`), and a birthday may have its own or none (`birthday/{id}.reminders`).
  The J-0 one carries « Souhaiter » (Android), which opens AnKi on the share sheet.
- **Book** — scanned by ISBN and looked up on Google Books; the seed of the gift-ideas feature.
- **Session** — the signed-in Firebase user: Google, email or anonymous, with an optional
  biometric lock.
