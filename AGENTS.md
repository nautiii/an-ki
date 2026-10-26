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

The main session keeps every judgement (design, briefs, decisions, the code that needs them) and
delegates the rest with a complete brief, since agents don't see the conversation:
`verifier` (Haiku) runs the checks of any verify step and returns only failures; `implementer`
(Sonnet) applies a fully specified mechanical change and sends back any open choice;
`device-runner` (Sonnet) makes every emulator or phone check; `reviewer` (Opus, high effort)
reviews the diff before every commit touching code or tooling; only markdown-only commits are exempt.

These steps are mandatory, not advice, in every session including side sessions: implement
(mechanical parts → `implementer`) → stage explicit paths → `verifier` and `reviewer` on that index
(in parallel) → commit. The reviewer runs once per commit, on the staged diff: apply its findings
(blocking ones included), re-stage, run the verifier again on the final index, then commit — no
second review. The verifier must pass on the exact staged index. This keeps token use reasonable.
A hook enforces it: `guard-git.sh` refuses a commit touching code (lib, test, platform, pubspec,
Firebase config) without the verifier's verdict for the staged tree and the reviewer's review since
the last commit, and any other commit that isn't markdown-only without the reviewer's
(`record-check.sh` records them on SubagentStop: the verifier bound to the tree it started on, an
index changed while it ran recording nothing; the reviewer bound to HEAD). The gate protects against forgetting, not against
deliberate bypass. Every change visible in the app also
goes through `device-runner` before the final report, or the report says « appareil : non vérifié »
and why.

## Stack

Flutter 3.47.6 · Dart 3.13.5 · Material 3 · Riverpod 3.4 (hand-written providers, no codegen) ·
Firebase Auth and Cloud Firestore (offline persistence on, no Storage) ·
flutter_local_notifications with timezone · share_plus (system share sheet) · gen-l10n (French
template, English).
Every dependency is pinned to an exact version.

## Commands

| Task | Command |
|------|---------|
| Dependencies | `flutter pub get` |
| Format | `dart format <files>` |
| Analysis — must be clean | `flutter analyze` and `dart analyze` (only the latter runs the `riverpod_lint` plugin) |
| Tests | `flutter test`, or `flutter test test/features/<feature>` |
| Firestore rules, in the emulator (Firebase CLI, Java 21+) | `scripts/test_firestore_rules.ps1` (firebase skill) |
| Strings, after any `.arb` change | `flutter gen-l10n` |
| Run on a device | `scripts/run.ps1 [-d <device id>]` (= `flutter run --dart-define-from-file=secrets.json`); agents start it in the Terminal panel (device skill) |
| Build and install an APK | `scripts/build_and_deploy.ps1 [-Release] [-Clean]` |
| Icon / splash, after changing their pubspec config | `dart run flutter_launcher_icons` · `dart run flutter_native_splash:create` |

The app reads `GOOGLE_BOOKS_API_KEY` from `secrets.json` through `--dart-define-from-file`.
In Claude Code, hooks (`.claude/settings.json`, scripts in `.claude/hooks/`) show the git state
at session start, format every `.dart` file right after it is written or edited, block blind,
merging or forced git commands and any Firebase command that writes production (the emulator,
read-only commands and a rules `--dry-run` pass), and ask the maintainer before a push or
anything that discards work, and refuse a commit without the agents' verdicts for the staged index
(`verifier` and `reviewer` for code, `reviewer` alone for other non-markdown files, nothing for
markdown-only commits); reading `secrets.json` is denied. Other agents follow the same
rules by hand.

## Code map

```
lib/main.dart       process start: Firebase, notifications, ProviderScope
lib/app/            composition root — MaterialApp, route table, shell (tabs), bootstrap; the only code that knows every feature
lib/core/           feature-agnostic — common/ (dumb shared widgets), theme/, services/ (plugin wrappers),
                    providers/, routing/ (route paths), extensions/, config/, constants/;
                    never imports app/ or a feature
lib/features/<f>/   auth · user · birthday · book_scanner · reminders · settings — domain/, data/, providers/, screens/, widgets/
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
  the shared `category` collection; multi-document writes go through `writeInBatches`.
- Ask before adding a package, a plugin, an Android permission or a data migration; pin exact
  versions (no `^`).
- Every change ships with tests at each layer it touches; aim for meaningful coverage close to
  100 %.
- Never read, print or commit secrets: `secrets.json`, `key.properties`, `*.jks`, `*.keystore`,
  `.env`. `android/app/google-services.json` is tracked on purpose (client config).

## Where to look

| Need | Read |
|------|------|
| Add or reshape behaviour: feature, model, repository, provider, service, Firestore shape, navigation, refactor, migration, structure review | `.claude/skills/architecture/SKILL.md` |
| Anything visual or interactive: screen, flow, states, theme, motion, copy, accessibility | `.claude/skills/ux-ui/SKILL.md` |
| Run, see or debug the app on the emulator or the phone: launch, screenshots, logs, dark mode, 200 % text, permissions, reminders | `.claude/skills/device/SKILL.md` |
| Firebase backend: security rules and their emulator tests, the data map, indexes, migrations, account deletion, console steps (deploy, SHA-1, flutterfire) | `.claude/skills/firebase/SKILL.md` |
| Commit, branch, pull request | `.claude/skills/git-workflow/SKILL.md` |
| Upgrade Flutter, packages or the Android toolchain | `/deps-upgrade` — only the maintainer starts it (`.claude/skills/deps-upgrade/SKILL.md`); asked for an upgrade otherwise, suggest it |
| Find and remove dead code: unused or test-only declarations, never-passed parameters, dead ARB keys | `/dead-code` — only the maintainer starts it (`.claude/skills/dead-code/SKILL.md`); asked for a cleanup otherwise, suggest it |
| Rules for the zone you edit: UI, state, data, navigation, reminders, tests, l10n, platform | `.claude/rules/*.md` — loaded automatically by Claude Code; other agents read the matching file |
| Why the architecture is what it is, and when to revisit it | `.claude/skills/architecture/references/decisions.md` |
| What to do next | `.claude/skills/ux-ui/references/ux-backlog.md` (product, UX) · `.claude/skills/architecture/references/migration.md` (code) |

## Glossary

- **Birthday** — a person (name, possibly empty surname, birth date whose year is optional),
  category ids, optional photo stored as base64 in the document, the years it was wished
  (`wishedYears`). Firestore `birthday/{id}`, owned through its `uid` field; an unknown year is
  stored as 2000 with `yearKnown: false`.
- **Category** (« groupe » in the UI) — a name, an icon and, for groups created since
  2026-10-24, a tone. Predefined ones live in the shared top-level `category` collection
  (Famille, Amis, Travail and Autres offered to everyone); groups a user creates are private,
  in `user/{uid}/categories`; `user/{uid}.categories` keeps the shared ones picked before. The
  « Groupes » page (Settings › Anniversaires) renames, recolours or deletes a private group and
  drops a shared one from the profile; its birthdays lose it either way. The four offered to
  everyone are locked.
- **User** — the profile document `user/{uid}`: name, surname, pseudo, categories, theme
  (`themeMode`: system, light or dark; an older `isDark` still reads), locale, biometric token.
- **Reminder** — local notifications on the day (J-0) and, by default, 7 days before (J-7), at
  10:00 device time; Settings › Anniversaires picks J-30, J-7, J-1 and the time
  (`user/{uid}.reminders`), and a birthday may have its own or none (`birthday/{id}.reminders`).
  The J-0 one carries « Souhaiter » (Android), which opens AnKi on the share sheet.
- **Book** — scanned by ISBN and looked up on Google Books; the seed of the gift-ideas feature.
- **Session** — the signed-in Firebase user: Google, email or anonymous, with an optional
  biometric lock.
