---
name: deps-upgrade
description: "Upgrade AnKi's stack: Flutter and Dart SDK, pub dependencies pinned to exact versions, riverpod_lint, Android toolchain (Gradle, AGP, Kotlin, google-services) within the range Flutter's tool knows. Inventory, changelogs and a plan first; IDEs and Dart processes closed before `flutter upgrade`; pub get outside Claude's sandbox; one commit per intent. `check` only reports."
disable-model-invocation: true
argument-hint: "[check | flutter | pub | android | <package>…]"
model: opus
effort: high
allowed-tools:
  - Bash(dart .claude/skills/deps-upgrade/scripts/inventory.dart *)
  - Bash(flutter pub outdated *)
  - Bash(dart pub add --dry-run *)
  - WebFetch(domain:docs.flutter.dev)
  - WebFetch(domain:github.com)
  - WebFetch(domain:docs.gradle.org)
  - WebFetch(domain:developer.android.com)
  - WebFetch(domain:kotlinlang.org)
---

# Upgrading AnKi's stack

The 2026-10-07 upgrade (Flutter 3.44.9 → 3.47.6, every package, Gradle/AGP/KGP) took a whole
session: `flutter upgrade` failed on files the IDE kept open, packages fetched from Claude's
sandboxed shell were invisible to the IDE's Gradle, the newest AGP was outside what Flutter
supports, and everything landed in one commit (`bf5f136`) that can be neither bisected nor
partly reverted. A package major can also break the look (google_fonts 9 did, bf5f136; the
package was removed in 2316591). Each step below avoids one of those.

The maintainer typed the command: that is a go for the inventory and the plan. Bumping still
waits for their go on the plan (`.claude/rules/platform.md`: approval, its own commit).

**Requested:** `$ARGUMENTS` — read it against this table (empty means everything).

| Argument | Scope |
|---|---|
| *(none)* | everything, in order: Flutter → pub → Android |
| `check` | inventory, changelogs and plan; writes nothing |
| `flutter` | the SDK and what it forces: constraints, formatter, migrators, generated l10n |
| `pub` | pub dependencies and riverpod_lint |
| `android` | Gradle, AGP, Kotlin Gradle plugin, google-services, desugar_jdk_libs |
| `<package>…` | only those packages, e.g. `timezone` |

## Rules

- **Flutter, then pub, then Android.** The SDK fixes the Dart version packages require and the
  Gradle/AGP/KGP range its tool supports: the other way round, work gets redone.
- **Stable only.** No alpha, beta, rc, `-dev` or `-pre`, no channel switch, no
  `dependency_overrides`, no `flutter upgrade --force`.
- **Pins.** `environment` keeps `sdk: ^<installed Dart>` and `flutter: ">=<installed Flutter>"`;
  riverpod_lint is pinned in `analysis_options.yaml`, outside the pubspec. `pubspec.lock` is tracked and travels with the
  pubspec.
- **Deliberate pins.** A package the inventory marks « épinglé dans decisions.md » is held back
  on purpose — go_router stays 17.x (decision D9). Read the decision before planning it; for
  any major, grep the rules and pubspec comments for the
  package too.
- **Android: the newest combination Flutter's tool knows,** not the newest release. The ceilings
  are constants in `packages/flutter_tools/lib/src/android/gradle_utils.dart`:
  `maxKnownAndSupportedGradleVersion` is what Flutter's CI tests, and Gradle stops at that exact
  version; the inventory prints the ceilings of the target Flutter, and `.claude/rules/platform.md`
  holds the current versions. For KGP, take one whose Kotlin compatibility table (kotlinlang.org,
  Gradle › configure project) covers the project's AGP and Gradle, else it was never tested with
  them (cdda03c). AGP also needs its minimum Gradle: a line wanting a Gradle above Flutter's
  ceiling stays out. `android.builtInKotlin=false` and `android.newDsl=false`:
  `.claude/rules/platform.md`.
- **Blocked packages** (`bloqué < x` in the inventory): `dart pub add --dry-run <pkg>:<version> …`
  names the constraint that fails. Use `dart`, not `flutter`: `flutter pub add --dry-run` still
  regenerates l10n and plugin files when the resolution succeeds. Report the blocker, leave the
  package. FlutterFire packages (`firebase_core`, `firebase_auth`, `cloud_firestore`) move
  together, and `fake_cloud_firestore` / `firebase_auth_mocks` pin their majors: they gate them.
- **Shared tree.** An upgrade rewrites `pubspec.*`, `android/` and sometimes every Dart file. Run
  `git status --short` first. `check` only reads: note what it sees and carry on. Otherwise, if
  those files or `lib/` and `test/` hold someone else's uncommitted work, stop and ask.

## 1. Inventory

```bash
dart .claude/skills/deps-upgrade/scripts/inventory.dart            # target: latest stable
dart .claude/skills/deps-upgrade/scripts/inventory.dart 3.48.0     # or a given Flutter, newer than the installed 3.47.9 (an older target isn't flagged)
```

Read-only, 10 to 20 s, network needed (« ? » otherwise). It prints:
- **Flutter**: installed version and channel, the target and its Dart, the pubspec constraints;
- **Android**: Gradle, AGP, KGP, google-services, desugar_jdk_libs — project, Flutter ceiling
  (read on GitHub for a target newer than the installed SDK), candidate, latest stable; an AGP
  line Flutter can't map to a minimum Gradle (« à vérifier »); `gradle.properties` flags that
  differ from Flutter's app template; the JDK;
- **pub**: direct and dev packages with a newer resolvable version — jump (`correctif`, `mineur`,
  `MAJEUR`; a 0.x minor counts as major), blocked, discontinued, retracted, advisory, pinned in
  `decisions.md`; the transitive packages `flutter pub upgrade` would move, with the Android and
  iOS implementations of plugins (`*_android`, `*_ios`, `*_darwin`) set apart; a raw changelog URL
  for each package that moves; riverpod_lint against pub.dev.

## 2. Changelogs, then the plan

Read the changelog of every direct bump and of every native implementation that moves: every entry
after the current version up to the target, not only the target's. Other transitive packages need
no reading.
- **Packages**: `curl -s <url>` on the URLs the inventory prints (the raw `CHANGELOG.md`). That
  file follows the default branch: skip the entries above the target (`NEXT`, pre-releases).
  WebFetch on pub.dev paraphrases and truncates long changelogs. For a major, grep `lib/` and
  `test/` for what it removes or renames, and read the plugin's setup page: manifest entry,
  permission, `minSdk`, iOS minimum (platform rule).
- **Flutter**: `docs.flutter.dev/release/release-notes`, `docs.flutter.dev/release/breaking-changes`;
  patch releases in `github.com/flutter/flutter/blob/stable/CHANGELOG.md`; Dart in
  `github.com/dart-lang/sdk/blob/main/CHANGELOG.md`.
- **Android**: `docs.gradle.org/<version>/release-notes.html`;
  `developer.android.com/build/releases/about-agp` (minimum Gradle and JDK per AGP line);
  `kotlinlang.org/docs/gradle-configure-project.html` (Gradle and AGP range per KGP).

The plan, in French, one line per bump: `from → to`, the jump, what it changes for us (« rien »,
or the API, screen or native setup it touches; native implementations name the device check) and
the commit it lands in. Then what stays behind and why: blocked, deliberately pinned, outside
Flutter's range. `check` stops here. Otherwise wait for the maintainer's go; they may strike any
line.

## 3. Where each command runs

Claude desktop is an MSIX app: from the Bash and PowerShell tools, writes under `%LOCALAPPDATA%`
land in a private overlay, so packages fetched there stay invisible to the IDE and to the Gradle
daemon it started (« Plugin directory does not exist: …\Pub\Cache\… »). The Terminal panel runs
outside that overlay (device skill: fetching there, `gradlew --stop`).
- **Fetch and build in the Terminal panel** (`run_in_terminal`, then `read_terminal`):
  `flutter upgrade`, `flutter pub get`, `flutter pub upgrade`, APK builds and `flutter run`.
  Without a Terminal panel, the maintainer runs them in their own terminal.
- **Read and check from the Bash tool**: the inventory, `flutter pub outdated`,
  `dart pub add --dry-run`, and `bash .claude/hooks/verify-index.sh` once the packages are fetched.
- A Gradle build started from Claude's shells anyway: `android\gradlew.bat --stop` afterwards, so
  the IDE never reuses that daemon.
- Prompts: `allowed-tools` (frontmatter) pre-approves the reads of the turn that starts the skill
  only (inventory, release notes, dry runs); the grant ends at the maintainer's next message.
  `model` and `effort` apply to that turn only too. The
  checks are allowed for good in `.claude/settings.json` (`flutter test` runs Dart code: that
  allow is an allow to execute code). Still asking on purpose: `curl` (a prefix rule would let
  extra URLs, `-d @file` or `-o` through while reading third-party changelogs) and
  `run_in_terminal` (an MCP rule can't filter the command).

## 4. Upgrade, one commit per intent

Before each commit, all green: `bash .claude/hooks/verify-index.sh` (format, project norms,
l10n, `dart analyze --fatal-infos`, tests). Commit through the git-workflow skill, step 4 (stage
in one call, commit the index in the next, after the checks and the reviewer; the gate refuses
paths after `git commit`). Messages name what actually moved (the titles below are patterns).
Docs quoting current versions change in the commit that changes the version: grep the old
version in `AGENTS.md`, `.claude/**/*.md` and `README.md` (019f3ef missed
`device/references/recipes.md`).

### a. Flutter — `BUILD: upgrade Flutter to <x.y.z>`

1. **Free the SDK.** `flutter upgrade` swaps `bin/cache/dart-sdk`, which Windows refuses while any
   program from it runs (« Rename-Item … utilisé par un autre processus »). List them:
   ```powershell
   Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -like '*\flutter\bin\cache\*' } | Select-Object ProcessId, ParentProcessId, Name, CommandLine
   ```
   Expect Android Studio or IntelliJ (`language-server`, `tooling-daemon`, `devtools`), each
   `flutter run` (flutter_tools, `frontend_server`, `development-service`) and the Dart MCP server
   (`mcp-server`) of every open Claude session, this one included. Ask the maintainer to close
   the IDEs and quit the runs; stop what remains (`Stop-Process -Id`) only with their OK. A
   session whose MCP server stopped loses its `mcp__dart__*` tools until it restarts. Never
   rename or delete anything inside the SDK.
2. **Upgrade** in the Terminal panel: `flutter upgrade`, then `flutter --version`. Local changes
   reported in the SDK checkout: stop and ask.
3. **Constraints.** Set `environment` to the new versions, `flutter pub get` (Terminal panel),
   `flutter gen-l10n`.
4. **Migrators.** Build once in the Terminal panel (`scripts/build_and_deploy.ps1`), and check
   the app on the device through the `device-runner` agent (otherwise the report says
   « appareil : non vérifié » and why): Flutter's migrators may rewrite `android/` files, and
   those edits belong to this commit. Compare `android/` with the app template
   (`packages/flutter_tools/templates/app/`: the two `build.gradle.kts` and `MainActivity.kt` in
   `android-kotlin.tmpl/`, the rest in `android.tmpl/`) and report drift instead of adopting it.
   `compileSdk`, `targetSdk`, `minSdk` and `ndkVersion` come from Flutter (`flutter.*` in
   `android/app/build.gradle.kts`): a Flutter bump changes them without a diff in `android/`,
   so it needs that device check.
5. **Formatter.** A new Dart language version can reformat code and add lints:
   `dart format lib test .claude/skills`. Commit `BUILD` first, then format and commit
   `STYLE: reformat with Dart <x.y> formatter` (`verify-index.sh` refuses an index while
   unstaged `.dart` changes remain); lint findings are fixed in the BUILD commit. A Flutter
   patch release on the same Dart usually changes nothing here.
6. **Second pubspec.** Check `.claude/skills/dead-code/scripts/pubspec.yaml` (analyzer 14.5.0,
   `sdk: ^3.13.5`): an analyzer that doesn't know the new language version gives wrong results
   without warning. After the upgrade, rerun the Dart scripts of `.claude/skills` (the analyzer
   skips `.claude/`; 6379a49).

### b. pub

- **Patches and minors needing no code**: set the pins to the inventory's targets,
  `flutter pub upgrade` in the Terminal panel (it moves the transitive packages and rewrites the
  lock, never the pins), one commit `CHORE(deps): bump pub dependencies`, a body line per direct
  package. A transitive raise of a minimum (image_picker_ios needs iOS 15, f8c5000) goes in the
  commit body and `.claude/rules/platform.md`.
- **Each major, and any bump that needs code**: its own `CHORE(deps): upgrade <pkg> to <x.y.z>`
  with the adaptation and its tests, so that every commit builds.
- **riverpod_lint** follows flutter_riverpod (pin in `analysis_options.yaml`), checked with
  `verify-index.sh`. The test-only interface pins (`google_sign_in_platform_interface`,
  `plugin_platform_interface`, used by `test/support/platform_mocks.dart`) move with their
  plugin, like the FlutterFire mocks.
- **A plugin or a native implementation moved**: run on the emulator through the `device-runner`
  agent and use the feature it serves — reminders (workmanager's daily replan, decision D12),
  contacts import, book scanner, biometric lock, Google sign-in, sharing, image_picker,
  flutter_secure_storage.

### c. Android — `BUILD(android): upgrade <what moved>`

- `android/gradle/wrapper/gradle-wrapper.properties` (`distributionUrl`), the `plugins` block of
  `android/settings.gradle.kts` (AGP, KGP, google-services), `coreLibraryDesugaring` in
  `android/app/build.gradle.kts`.
- A clean build in the Terminal panel (`scripts/build_and_deploy.ps1 -Clean`): read every Gradle
  warning (« Flutter support for … will soon be dropped », plugins applying KGP), then run on
  the emulator through the `device-runner` agent.
- The icon and splash generators rewrite `android/` and `ios/`: rerun them only when their
  config changes.

## 5. Report

In French: what moved (`from → to`) and in which commit (`git log --oneline -<n>`), what stayed
behind and why, what ran (`verify-index.sh`, build, emulator) and what didn't (the
phone; iOS, never built on this setup). Remind the maintainer to reopen their IDE, which restarts
its analysis server on the new SDK.
