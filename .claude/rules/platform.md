---
paths:
  - "android/**"
  - "ios/**"
  - "lib/core/services/**"
  - "pubspec.yaml"
---

# Platform code — Android, iOS, plugin wrappers, dependencies

## Android (`android/`)

- Toolchain: Gradle 9.3.1, AGP 9.1.1, Kotlin Gradle plugin 2.4.10, google-services 4.5.0 — the
  newest combination within Flutter 3.47.6's tested range; Java/Kotlin target 17, builds run on
  JDK 21. Keep `android.builtInKotlin=false` and `android.newDsl=false` (written by Flutter's
  migrator; plugins that apply KGP break on AGP 9 otherwise). Bumping any of them is a toolchain
  upgrade: approval and its own `BUILD` commit.
- Application id `com.github.nautiii.an_ki`; `minSdk`/`targetSdk` come from Flutter; core library
  desugaring stays on (flutter_local_notifications needs it).
- `MainActivity` (a `FlutterFragmentActivity`, which `local_auth` needs) hosts one method channel,
  `an_ki/notification_permission` (`canAskAgain`): what flutter_local_notifications doesn't
  expose, read by `NotificationService` (`reminders.md`). Native code stays that small: a plugin
  API that exists wins over a new channel.
- `app/google-services.json` is tracked on purpose (client config, not a secret). A new signing
  key needs its SHA-1 registered in the Firebase console by the maintainer, or Google Sign-In
  fails.
- Release builds are still signed with the debug key (`app/build.gradle.kts`): publishing needs a
  real signing config first. Never commit a keystore or `key.properties`.
- Manifest permissions are user-facing and store-policy-sensitive: add or remove one only with
  approval. Google Play restricts `USE_EXACT_ALARM` to alarm-clock and calendar apps;
  `SCHEDULE_EXACT_ALARM` isn't granted by default on Android 14+. The
  `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` entries are required by
  flutter_local_notifications (reboot, app update).
- Launcher icons and splash resources are generated from the pubspec config
  (`dart run flutter_launcher_icons`, `dart run flutter_native_splash:create`): change the config,
  not the PNGs.

## iOS (`ios/`)

Never built on the current setup: deployment target 12.0 and no Podfile, while Firebase needs
iOS 15 and flutter_secure_storage iOS 13. Keep the Dart code platform-correct; don't touch `ios/`
without a plan to build it.

## Web

No web target (`web/` removed). `lib/core/firebase_options.dart` and
`firebase.json` still describe the Firebase web app until the maintainer reruns flutterfire
(firebase skill, `references/console.md` §5).

## Plugin wrappers (`lib/core/services/`)

- A service is a thin, stateless door to a plugin: no business rule, no policy (*when* to remind
  is a domain rule of the `reminders` feature, `reminder_plan.dart`), no text of its own (the
  one exception: `NotificationService`'s French fallback texts, replaced by the ARB ones at
  startup), no feature import. Features map their objects onto `core` value objects
  (`ReminderNotification`, `ImportedBirthday`).
- `.instance` singletons serve `main()` initialization and provider defaults
  (`notificationServiceProvider`, `biometricServiceProvider`, `firestoreProvider`…), or sit inside
  a plugin wrapper (`share_service.dart`); everything else reads the provider, so tests can
  override it. Keep the `@visibleForTesting` constructors.
- Unit tests can't prove platform behaviour (permissions, scheduled notifications, biometrics,
  camera): check it on a device (device skill) and say on which one, or that it wasn't.

## Dependencies (`pubspec.yaml`)

- Exact versions only, no `^`. A new package or plugin needs approval and a reason; record it in
  `decisions.md` when it's structural.
- A plugin may need a manifest permission, a higher `minSdk` or iOS version: apply its setup
  steps in the same change.
- After a dependency change: `flutter pub get`, `flutter analyze`, `dart analyze`, the full test
  suite, and a run on a device when a plugin changed.
- Upgrades (Flutter, packages, Gradle/AGP/KGP) follow `/deps-upgrade`, which only the maintainer
  starts: asked to upgrade otherwise, suggest the command rather than improvising the procedure.
