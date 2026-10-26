---
name: device
description: "Run, see and debug AnKi on a real Android system: the Honor_Magic7_Pro emulator by default, the maintainer's phone over USB on request. Boots the emulator, launches with secrets.json from the Terminal panel, hot reloads through the Dart MCP server, takes screenshots Claude reads back, lists the UI and taps by label, filters logcat and crashes, switches dark mode, 200 % text, compact screen, offline, reduced motion and permissions, moves the clock to fire reminders, reads scheduled alarms and posted notifications, seeds test contacts. Use whenever a change must be seen or checked in the running app, not only in tests; it is the project skill the built-in run skill looks for. Trigger even on short or French asks: « lance l'app », « teste sur l'émulateur / le téléphone », « fais une capture de l'app », « ça plante », « regarde les logs », « le rappel part ? », « installe l'APK ». Not for host-side widget tests or PNG snapshots (ux-ui)."
effort: low
---

# AnKi on a device — launch, observe, vary

Tests and the ux-ui snapshots render AnKi's widgets on the host. Only a device shows what people
get: Outfit downloaded by google_fonts (snapshots fall back to Roboto), colour emoji, Android's
nonlinear 200 % text, the system bars, permission dialogs, alarms and notifications, contacts,
Firestore offline, real startup. This skill puts the app on a device and brings back evidence:
screenshots you open with Read, the UI tree, logs, the system's own dumps.

Talk to the maintainer in French; commands, file names and commit messages stay in English.

## Devices

| | `Honor_Magic7_Pro` emulator — default | Maintainer's phone |
|---|---|---|
| What | AVD shaped like an Honor Magic7 Pro: 1280 × 2800 px at 480 dpi (427 × 933 dp), Android 16 (API 36), Google APIs x86_64 (Play services, no Play Store), system in French, Europe/Paris | the real phone, over USB |
| Serial | `emulator-5554` | `adb devices`, then `DEVICE=<serial>` before each command |
| Allowed | everything below, `adb root` included | observe and drive the app; settings you vary are restored by `reset`; never `time`, `contact` or a data wipe |
| Best for | every check an agent runs | real performance, the camera (book scanner), MagicOS behaviour, when asked |

**Session.** Agents never type passwords or create accounts, anonymous ones included: ask the
maintainer to sign in on the emulator once; Firebase keeps the session on the device. Google
Sign-In needs the debug key's SHA-1 in Firebase (platform rule): e-mail works meanwhile.

## Where each command runs

Claude desktop is an MSIX app. In Claude's own shells (Bash and PowerShell tools), writes under
`%APPDATA%` and `%LOCALAPPDATA%` are virtualized and Java NIO can't open a selector, so Gradle
fails and downloaded packages stay invisible to the IDE. The app's **Terminal panel** runs
outside that sandbox. So:
- **Builds** (`flutter run`, `scripts/build_and_deploy.ps1`, `flutter pub get`) go to the
  Terminal panel with `run_in_terminal`: the maintainer sees the tab and can type `r`, `R`, `q`.
- **adb, the emulator and `device.sh`** run from the Bash tool: no Java involved.
- No Terminal panel (plain CLI session): `references/recipes.md` §13.

## Workflow

1. **Boot.** `bash .claude/skills/device/scripts/device.sh boot` prints the serial. It starts the
   AVD detached when needed (≈ 20 s from the snapshot, ≈ 1 min cold), restores Europe/Paris and
   lifts the lock screen. Phone: `adb devices`, then prefix each command with `DEVICE=<serial>`.
2. **Launch** in the Terminal panel: `run_in_terminal` with
   `& '.\scripts\run.ps1' -d emulator-5554 --print-dtd`, titled « AnKi · <device> ». Poll
   `read_terminal` (`wait_for_output_ms: 60000`) until « Flutter run key commands », or until a
   Gradle or Dart error, which you fix first. The first build takes ≈ 5 min.
   - Installed already, nothing to rebuild: `device.sh start` (prints LaunchState and TotalTime).
   - Release, for startup time and smoothness: `run_in_terminal` with
     `$env:ANDROID_SERIAL = 'emulator-5554'; & '.\scripts\build_and_deploy.ps1' -Release`.
3. **Observe.** `device.sh shot <name>` prints a Windows path: open it with Read. `device.sh ui`
   lists each labelled element as `label | class | x,y`. `logs`, `crash`, `alarms` and `notifs`
   give the system's side.
4. **Drive.** `tap <label>` (exact label first, else the first one containing it, case
   ignored), `tap <x> <y>`, `type`, `key back`, `scroll down`. After a navigation or a setting
   change, wait about a second and run `ui` again before the next step: a tap sent during a
   transition is lost.
5. **Iterate.** After an edit, hot reload: the Dart MCP `hot_reload` (below), or ask the
   maintainer to press `r` in the tab. Hot restart (`R`) for provider wiring, `initState`,
   routes; a full relaunch (`stop_terminal_tab`, then step 2) for native code, plugins, the
   manifest or `pubspec.yaml`.
6. **Vary.** `theme dark`, `text 2.0`, `size compact` (360 × 640 dp), `motion off`, `net off`,
   `tz`, `time`, `perm`, `contact`. The first display, motion, network, clock or time-zone
   variation records the device's settings and `reset` puts them back: run it before you
   finish, on every device you touched. `reset` leaves permissions and contacts alone: undo them
   with `perm reset <permission>` and `contact clear`.
7. **Clean up.** Close the run tab (`stop_terminal_tab`, `close: true`) when you are done. Leave
   the emulator running, the maintainer may be using it; `adb -s emulator-5554 emu kill` stops
   it and saves the quick-boot snapshot.
8. **Report** in French: device and build mode, what you checked with the screenshot paths,
   what you couldn't check (camera, phone-only behaviour, a flow behind sign-in).

## Dart MCP server — hot reload and live state

`.mcp.json` declares a `dart` server (`dart mcp-server`, details in `references/recipes.md` §14);
Claude Code asks to approve it once, and its tools are `mcp__dart__*`. When it is connected:
`dtd` with `listDtdUris` finds the run started with `--print-dtd` (its « Workspace Root » is the
repo), `connect` attaches to it, then `hot_reload` (0.3 to 1.5 s), `hot_restart`,
`get_runtime_errors` and `widget_inspector` `get_widget_tree` with `summaryOnly: true`. Never
launch through it: `launch_app` forwards `--dart-define` but not `--dart-define-from-file`, so
the Google Books key would pass through the agent.

## `device.sh`

`bash .claude/skills/device/scripts/device.sh <command>`; `help` lists everything. Target:
`$DEVICE`, else the only device, else the emulator.

| Need | Commands |
|---|---|
| Device | `boot` · `info` · `start` · `stop` (a force-stop also drops the app's alarms until it reopens) |
| See | `shot [name]` → `build/device/<name>.png` · `ui` · `logs [n]` (app process: warnings and Dart prints) · `crash [n]` |
| Reminders | `alarms` (AlarmManager entries, plus the plugin's own schedule on debug builds) · `notifs` (title and text) |
| Drive | `tap <label>` · `tap <x> <y>` · `type <ASCII text>` · `key back\|home\|enter\|tab\|del\|recents` · `scroll down\|up` |
| Vary | `theme dark\|light` · `text <scale>` · `size compact\|reset\|<W>x<H>` · `motion off\|on` · `net off\|on` · `tz <zone>` · `time +3d\|+2h\|+10m\|'YYYY-MM-DD HH:MM'\|auto` (emulator) |
| Permissions | `perm` (state) · `perm grant\|revoke\|reset notifications\|contacts\|camera` |
| Fixtures | `contact "<name>" YYYY-MM-DD` · `contact "<name>" --MM-DD` (unknown year) · `contact clear` (emulator) |
| Undo | `reset` |

`references/recipes.md` has the rest: TalkBack, display size, the notification shade, screen
recording, fingerprint, release startup, the system language, the AVD itself, a reminder end to
end, the phone, the Dart MCP setup.

## Gotchas

- Revoking a permission (`perm revoke` or `perm reset`) makes Android kill the app: `flutter run`
  prints « Lost connection to device », relaunch it.
- A cold boot puts the emulator back on GMT (it can't read Windows' zone) and `boot` fixes it.
  Reminders fire at 10:00 *device* time.
- The app's language comes from the profile (French by default), not from the system: the
  system language only changes Android's dialogs and pickers.
- Switching the system theme while the app runs can leave dark status-bar icons on a dark
  screen without an `AppBar` (the welcome screen sets its own through `AnnotatedRegion`):
  cold-start in dark mode before judging the bars.
- Outfit is downloaded on the first launch (into the app's `files/`): an offline first run shows
  the fallback font.
- Debug timings are JIT timings (3 to 4.5 s to start on the emulator): measure startup in
  release only.
- `type` is ASCII only. `ui` and `tap` see only what Flutter exposes to accessibility: an element
  without a label is invisible to them, which is an accessibility finding in itself. A tile's
  semantics merge into one label (« Camille Martin / 15 mars »): tap any part of it.
- Git Bash turns `/sdcard/x` into `C:/Program Files/Git/sdcard/x` for `adb.exe`: export
  `MSYS_NO_PATHCONV=1` before raw adb commands (`device.sh` does). In PowerShell never redirect
  binary output (`exec-out screencap > x.png` corrupts it): `adb shell screencap -p /sdcard/x.png`
  then `adb pull`.
- `ping` doesn't work in the emulator: `device.sh info` shows airplane mode, or run
  `adb shell nc -z 8.8.8.8 53`.
- The emulator renders with Impeller on OpenGL ES, the phone on Vulkan: settle a rendering doubt
  on the phone.
- `flutter gen-l10n` (run by every build) writes `lib/l10n/app_localizations*.dart` with
  `pubspec.yaml`'s line endings: keep `pubspec.yaml` in LF (`.gitattributes`), or every build
  shows the l10n files as changed.

## Never

- Type a password, create an account, or accept terms or a consent on the maintainer's behalf.
- Change the clock, write contacts, `pm clear`, uninstall or wipe anything on the phone: it is
  the maintainer's own. On the emulator, `pm clear com.github.nautiii.an_ki` and `-wipe-data`
  erase the session and local data: ask first.
- Read or print `secrets.json` or the app's secure storage (`FlutterSecureKeyStorage.xml`).
