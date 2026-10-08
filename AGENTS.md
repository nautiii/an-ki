# AnKi — agent guide

AnKi (暗記, *learn by heart*; repo **kairos**, *the right moment*) is a Flutter app that makes sure
you never miss the birthday of someone you care about. Three user jobs, by frequency:
**see who's next** (daily, in under 2 s), **act on it** (wish, find a gift), **capture** (add or
import a birthday in under 10 s). Data syncs through Firebase and works offline; reminders are
scheduled on the device so they fire without network. Android first: the maintainer tests on a
physical phone over USB. iOS must stay correct but hasn't been built on the current setup.

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
- Show, don't claim: say what you ran (format, analyze, tests, phone) and what you didn't.

## Stack

Flutter 3.47.6 · Dart 3.13.5 · Material 3 · Riverpod 3.4 (hand-written providers, no codegen) ·
Firebase Auth and Cloud Firestore (offline persistence on, no Storage) ·
flutter_local_notifications with timezone · gen-l10n (French template, English).
Every dependency is pinned to an exact version.

## Commands

| Task | Command |
|------|---------|
| Dependencies | `flutter pub get` |
| Format | `dart format <files>` |
| Analysis — must be clean | `flutter analyze` and `dart analyze` (only the latter runs the `riverpod_lint` plugin) |
| Tests | `flutter test`, or `flutter test test/features/<feature>` |
| Strings, after any `.arb` change | `flutter gen-l10n` |
| Run on the phone | `scripts/run.ps1` (= `flutter run --dart-define-from-file=secrets.json`) |
| Build and install an APK | `scripts/build_and_deploy.ps1 [-Release] [-Clean]` |
| Icon / splash, after changing their pubspec config | `dart run flutter_launcher_icons` · `dart run flutter_native_splash:create` |

The app reads `GOOGLE_BOOKS_API_KEY` from `secrets.json` through `--dart-define-from-file`.
In Claude Code, a hook (`.claude/settings.json`) formats every `.dart` file right after it is
written or edited, and reading `secrets.json` is denied; other agents run `dart format`
themselves.

## Code map

```
lib/main.dart       process start: Firebase, notifications, ProviderScope
lib/app/            composition root — MaterialApp, route table, bootstrap; the only code that knows every feature
lib/core/           feature-agnostic — common/ (dumb shared widgets), theme/, services/ (plugin wrappers),
                    providers/, extensions/, config/; never imports app/ or a feature
lib/features/<f>/   auth · user · birthday · book_scanner · home — data/, providers/, screens/, widgets/
lib/l10n/           intl_fr.arb (template) + intl_en.arb; app_localizations*.dart are generated
test/               mirrors lib/; test/support/ holds the widget harness and shared fakes
scripts/            PowerShell: run, build and deploy
```

## Architecture: target vs today

Target: feature-first layered MVVM — `screens/ widgets/ → providers/ → data/ → domain/` inside
each feature, features linked by a declared acyclic graph, rules enforced by
`test/architecture/architecture_test.dart` (known debt listed there, it only shrinks). Today's
code predates the target; the plan is `.claude/skills/architecture/references/migration.md`
(M0 done, next M1–M8).

- Never copy a legacy pattern into new code: session handling with `startListening`/`clear()`,
  `XState` with `isLoading`/`errorMessage` strings, `AppLocalizations` passed to notifiers,
  `.instance` singletons read by features, `FirebaseFirestore.instance` defaults, raw route
  strings, `DateTime.now()` outside the clock provider, models importing Firestore or Flutter.
- Don't migrate opportunistically either: a bug fix stays a bug fix. Structural moves follow the
  plan, one step per commit, behaviour locked by tests first.

## House rules — every task

- Absolute imports only: `package:an_ki/...`.
- No hardcoded user-facing string (ARB, French template + English) or color (theme only); dates
  through `intl` `DateFormat` with the locale.
- Widgets render state and forward intents; logic lives in providers and pure domain functions;
  no Firebase or repository call from a widget.
- Riverpod 3 only: never `StateNotifier` or `legacy.dart`; after any `await` in a notifier, check
  `ref.mounted` before touching `state`.
- No code generation (freezed, json_serializable, riverpod_generator, build_runner). Models are
  immutable: `final` fields, `const` constructor, `copyWith`, `==`/`hashCode`.
- Strong typing: no `dynamic` in app code (analyzer strict modes are on); `const` wherever
  possible; past ~300 lines, split a widget into private widget classes.
- Every Firestore read and write is scoped to the signed-in user (path or `uid` filter);
  multi-document writes go in a `WriteBatch`.
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
| Commit, branch, pull request | `.claude/skills/git-workflow/SKILL.md` |
| Rules for the zone you edit: UI, state, data, tests, l10n, platform | `.claude/rules/*.md` — loaded automatically by Claude Code; other agents read the matching file |
| Why the architecture is what it is, and when to revisit it | `.claude/skills/architecture/references/decisions.md` |
| What to do next | `.claude/skills/ux-ui/references/ux-backlog.md` (product, UX) · `.claude/skills/architecture/references/migration.md` (code) |

## Glossary

- **Birthday** — a person (name, surname, birth date with year), category ids, optional photo
  stored as base64 in the document. Firestore `birthday/{id}`, owned through its `uid` field.
- **Category** (« catégorie ») — a label with an icon. Documents in the shared top-level
  `category` collection; each user picks theirs in `user/{uid}.categories`.
- **User** — the profile document `user/{uid}`: name, pseudo, categories, theme, locale.
- **Reminder** — local notifications on the day (J-0) and 7 days before (J-7), at 10:00 device time.
- **Book** — scanned by ISBN and looked up on Google Books; the seed of the gift-ideas feature.
- **Session** — the signed-in Firebase user: Google, email or anonymous, with an optional
  biometric lock.
