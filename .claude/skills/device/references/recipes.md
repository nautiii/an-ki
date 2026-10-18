# Device recipes

Raw commands beyond `device.sh`, for Git Bash. Set `MSYS_NO_PATHCONV=1` first (or device paths
such as `/sdcard/x` get rewritten); from then on give Windows programs relative or Windows paths
for host files (`$(cygpath -w …)`), a `/c/…` path no longer reaches them. Use the SDK's adb
(`"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`, called `adb` below), add `-s <serial>`
when several devices are attached, and strip `\r` from adb output (`| tr -d '\r'`).
Everything here ran on the emulator on 2026-10-16, except what §15 lists.

1. [The AVD](#1-the-avd) · 2. [The phone](#2-the-phone) · 3. [Logs](#3-logs) ·
4. [Screens and recordings](#4-screens-and-recordings) · 5. [Accessibility pass](#5-accessibility-pass) ·
6. [A reminder end to end](#6-a-reminder-end-to-end) · 7. [Permissions and app settings](#7-permissions-and-app-settings) ·
8. [Contacts for the import](#8-contacts-for-the-import) · 9. [Fingerprint](#9-fingerprint) ·
10. [Camera](#10-camera) · 11. [App data](#11-app-data) · 12. [Release startup](#12-release-startup) ·
13. [Fallback build](#13-fallback-build-without-the-terminal-panel) · 14. [Dart MCP server](#14-dart-mcp-server) ·
15. [Not verified yet](#15-not-verified-yet)

## 1. The AVD

- Created by the maintainer on 2026-10-16 in Android Studio's Device Manager: hardware profile
  « Honor Magic7 Pro » (`~/.android/devices.xml`), AVD `~/.android/avd/Honor_Magic7_Pro.avd/`
  (`config.ini`): system image `android-36/google_apis/x86_64`, 2 GB RAM, 4 cores, quick boot,
  WHPX acceleration. The screen was first entered as 2800 × 1280 (a landscape phone); both files
  now say 1280 × 2800. If Android Studio offers to « repair » the AVD, check the size after.
- Emulator flags (`"$LOCALAPPDATA/Android/Sdk/emulator/emulator.exe" -avd Honor_Magic7_Pro …`):
  `-no-snapshot-load` cold boot · `-no-snapshot-save` leave the snapshot as it is ·
  `-no-window` headless · `-timezone Europe/Paris` (`device.sh boot` passes it) ·
  `-wipe-data` factory reset: erases the signed-in session and the contacts, ask first.
- A killed emulator stays « offline » in `adb devices` for a few seconds: `device.sh boot` asks
  the emulator console (`adb emu avd name`) instead of trusting that list.
- System language, once per factory reset (needs root, then a reboot):
  ```bash
  adb root && adb wait-for-device shell 'setprop persist.sys.locale fr-FR; settings put system system_locales fr-FR' && adb reboot
  bash .claude/skills/device/scripts/device.sh boot
  ```
  `system_locales` wins over the property: setting only `persist.sys.locale` leaves English.
- To mirror the phone exactly, read `adb shell wm size` and `adb shell wm density` on the phone,
  stop the emulator, set `hw.lcd.width`, `hw.lcd.height` and `hw.lcd.density` in `config.ini`,
  then cold boot. A quick tweak without editing: `adb shell wm density <dpi>` (undo with
  `device.sh size reset`).

## 2. The phone

- The maintainer enables USB debugging and accepts the PC's key on the phone; `adb devices -l`
  then lists it with its serial. Every `device.sh` call takes `DEVICE=<serial>`.
- Launch: `run_in_terminal` with `& '.\scripts\run.ps1' -d <serial> --print-dtd`. Profile mode,
  for frame timings in DevTools, works on the phone only: add `--profile`.
- Allowed: observe, drive the app, vary display settings (`reset` puts the maintainer's own
  values back). Not allowed: the clock, contacts, data wipes, uninstalling (see SKILL.md, Never).
- MagicOS may delay or drop exact alarms of apps it puts to sleep: when a reminder doesn't fire
  on the phone while `alarms` showed it, check the phone's battery and app-launch settings for
  AnKi before suspecting the code.

## 3. Logs

- Clear before a scenario so the dump shows only it: `adb logcat -c`.
- App process only: `adb logcat -d -v time --pid=$(adb shell pidof -s com.github.nautiii.an_ki | tr -d '\r') '*:W' flutter:I`
  (`device.sh logs` does this, and falls back to the `flutter` and `AndroidRuntime` tags when
  the app is not running).
- Tags worth a filter: `flutter` (`print`, `debugPrint`, Flutter errors), `AndroidRuntime`
  (Java crash), `Firestore`, `FirebaseAuth`. Native crashes: `adb logcat -d -b crash`.
- Follow live with the Monitor tool, one event per error line:
  ```bash
  MSYS_NO_PATHCONV=1 adb logcat -v time -T 1 '*:E' flutter:I | grep --line-buffered -E 'E/|Exception|Error'
  ```
- The app logs `[NotificationService] N reminder(s) scheduled.` at every start: the quickest
  proof that reminders were (re)planned.

## 4. Screens and recordings

- Screenshot: `device.sh shot <name>`. Big PNGs are downscaled by Read: to judge a detail (the
  status bar, an icon), crop the PNG before reading it.
- Notification shade: `adb shell cmd statusbar expand-notifications`, `device.sh shot`, then
  `adb shell cmd statusbar collapse`.
- A video for the maintainer (Claude can't watch one): `adb shell screenrecord --time-limit 15 /sdcard/anki.mp4`,
  `adb pull /sdcard/anki.mp4 build/device/`, `adb shell rm /sdcard/anki.mp4`. The encoder can't
  do 1280 × 2800 and falls back to 720 × 1280 by itself.
- Settings screens: AnKi's notifications
  `adb shell am start -a android.settings.APP_NOTIFICATION_SETTINGS --es android.provider.extra.APP_PACKAGE com.github.nautiii.an_ki`,
  app info `adb shell am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.github.nautiii.an_ki`.

## 5. Accessibility pass

The manual pass of `ux-ui/references/accessibility.md`, with commands:
1. TalkBack on:
   `adb shell 'settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService; settings put secure accessibility_enabled 1'`;
   off: `adb shell 'settings put secure enabled_accessibility_services ""; settings put secure accessibility_enabled 0'`.
   With TalkBack on, a tap only moves the focus and speech can't be heard from here: the
   maintainer listens; the agent reads `device.sh ui`, which shows the same labels. The first
   start asks to let « Outils d'accessibilité Android » post notifications: decline.
2. Largest text and display: `device.sh text 2.0`, `adb shell wm density 560`.
3. Dark theme and reduced motion: `device.sh theme dark` (then cold-start the app, see SKILL.md
   gotchas) and `device.sh motion off`.
4. One-handed reach: judge it on the screenshot, primary action in the bottom half.
Finish with `device.sh reset`.

## 6. A reminder end to end

Needs a signed-in session; not run yet (§15). `reminder_plan.dart` plans J-0 and J-7 at 10:00;
a reminder whose 10:00 is already past moves to the next year.
1. In the app, add a birthday for tomorrow and one 8 days from now: both remind tomorrow at
   10:00 (J-0 and J-7).
2. `device.sh alarms`: one `RTC_WAKEUP` entry per reminder at 10:00; on a debug build the
   plugin's schedule follows (titles and dates).
3. `device.sh time 'YYYY-MM-DD 09:59'` with tomorrow's date, wait a minute or two, then
   `device.sh notifs` and a shot of the shade (§4).
4. `device.sh reset`: the clock goes back to network time.
Jumping the clock forward fires every alarm in between at once. Each notification repeats on
the same date every year (`DateTimeComponents.dateAndTime`), so a fired one stays planned.

## 7. Permissions and app settings

- `device.sh perm` shows the runtime permissions (notifications, contacts, camera); `grant`,
  `revoke`, and `reset` (revoke and clear « user-set / user-fixed », so the app asks again
  as on a fresh install). Revoking kills the app.
- Exact alarms: AnKi declares `USE_EXACT_ALARM` (granted at install, not revocable), so the
  `SCHEDULE_EXACT_ALARM` app-op doesn't change anything while it stays in the manifest.
- Notifications shown or not for the app: the settings screen of §4.

## 8. Contacts for the import

- `device.sh contact "Camille Martin" 1990-03-15`, `device.sh contact "Mamie" --07-02` (no
  year: Android stores `--MM-DD`), names with accents and apostrophes work. They are local
  contacts of the emulator; `device.sh contact clear` removes them all.
- Check them in the Contacts app:
  `adb shell am start -n com.google.android.contacts/com.android.contacts.activities.PeopleActivity`.
- Three fixtures exist on the AVD since 2026-10-16: Camille Martin (1990-03-15), Mamie
  (--07-02), Léa Dupont (2001-10-23).

## 9. Fingerprint

The biometric lock needs a screen lock and an enrolled finger on the device: the maintainer sets
them once (Settings › Sécurité): agents don't change the lock screen. On the emulator, each
« touch the sensor » step and AnKi's own prompt accept `adb -s emulator-5554 emu finger touch 1`
(the enrolled finger); `emu finger touch 2` is an unknown finger, for the failure path.

## 10. Camera

The emulator's back camera is a virtual 3D room (`hw.camera.back=virtualscene`), the front one
a test pattern: ISBN scanning is a phone check. An image can be hung in the room at boot with
`-virtualscene-poster wall=<file.png>`, but reaching it means walking there by hand in the
emulator window.

## 11. App data

Debug builds only (`run-as` refuses release builds):
`adb shell run-as com.github.nautiii.an_ki ls -la files shared_prefs`.
- `files/Outfit_*.ttf`: the fonts google_fonts downloaded.
- `shared_prefs/notification_plugin_cache.xml`: the notification plugin's own schedule
  (`device.sh alarms` prints it).
- Never print `FlutterSecureKeyStorage.xml` or the secure-storage files: they hold keys.

## 12. Release startup

Job 1 is « who's next, in under 2 s »; measure it on a release build only:
1. `run_in_terminal` with `$env:ANDROID_SERIAL = 'emulator-5554'; & '.\scripts\build_and_deploy.ps1' -Release`
   (the script also regenerates the icons and the splash: check `git status` after).
2. `device.sh stop`, then `device.sh start` three times; keep the TotalTime of the cold start
   (`LaunchState: COLD`) and the median of the warm ones. The phone gives the number that
   counts; the emulator only shows a trend.

## 13. Fallback build without the Terminal panel

Plain CLI sessions have no `run_in_terminal`. From the Bash tool, with `run_in_background`:
```bash
mkdir -p ~/.gradle/tmp-af build/device
JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=$(cygpath -w ~/.gradle/tmp-af)" \
  flutter run -d emulator-5554 --dart-define-from-file=secrets.json --print-dtd > build/device/run.log 2>&1
```
- Without `JAVA_TOOL_OPTIONS`, Java fails with « Unable to establish loopback connection »
  (an AF_UNIX socket in the virtualized temp folder); with it, a selector opens.
- Wait with a background `until grep -qE 'Flutter run key commands|Error|FAILURE|Exception' build/device/run.log; do sleep 2; done`.
- No stdin: hot reload goes through the Dart MCP server only.
- Afterwards `android/gradlew.bat --stop`, so the IDE doesn't reuse a daemon born in Claude's
  sandbox. Never fetch a new package from there: it would land in Claude's virtual pub cache,
  invisible to the IDE; the maintainer runs `flutter pub get`.

## 14. Dart MCP server

`dart mcp-server` ships with the Dart SDK (server 1.2.0 with Dart 3.13.5). Declared since
2026-10-16 in `.mcp.json` at the repo root, which Claude Code asks to approve once (a session
started before that file sees no `mcp__dart__*` tools until it restarts):
```json
{
  "mcpServers": {
    "dart": { "command": "cmd", "args": ["/c", "dart", "mcp-server", "--disable", "pub"] }
  }
}
```
- `cmd /c`: Claude Code can't start `dart.bat` directly on Windows. `--disable pub`: package
  changes stay with the maintainer (§13).
- On by default: `dtd`, `hot_reload`, `hot_restart`, `get_runtime_errors`, `widget_inspector`,
  `vm_service`, `analyze_files`, `lsp`, package readers. `launch_app`, `run_tests` and
  `dart_format` stay off unless `--enable`d: keep it so (SKILL.md, Dart MCP server).
- Checked on 2026-10-16 with the app launched from the Terminal panel: `listDtdUris` also lists
  Android Studio's daemon (its root is the Dart SDK), connect to the one whose root is the repo.
  `flutter_driver_command` needs the driver extension, which AnKi doesn't enable.

## 15. Not verified yet

- §6 (a reminder firing): needs the maintainer's sign-in on the emulator.
- Step 4 of the UX roadmap (2026-10-18): the J-0 hero and its petals, the share sheet of
  « Souhaiter », the J-0 notification's « Souhaiter » button: the build installs and starts,
  the rest waits for that sign-in.
- §9 enrolment and AnKi's biometric prompt: the console accepted `finger touch`, nothing was
  enrolled.
- §12 release build and timings, §2 on the phone (none was plugged in), §10 poster.
- `motion off` sets Android's animation scales to 0; whether AnKi's animations honour it
  (`MediaQuery.disableAnimations`) wasn't checked.
