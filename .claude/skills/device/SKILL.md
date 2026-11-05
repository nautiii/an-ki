---
name: device
description: "Run, see and debug AnKi on a real Android system: the Honor_Magic7_Pro emulator by default, the maintainer's phone over USB on request. One emulator shared by every session through a first-come queue (claim, release), booted and repaired on demand; launches with secrets.example.json from the Terminal panel, hot reloads through the Dart MCP server, takes screenshots Claude reads back, lists the UI and taps by label, filters logcat and crashes, switches dark mode, 200 % text, compact screen, offline, reduced motion and permissions, moves the clock to fire reminders, reads scheduled alarms and posted notifications, seeds test contacts. Use whenever a change must be seen or checked in the running app, not only in tests; it is the project skill the built-in run skill looks for. Trigger even on short or French asks: « lance l'app », « teste sur l'émulateur / le téléphone », « fais une capture de l'app », « ça plante », « regarde les logs », « le rappel part ? », « installe l'APK », « l'émulateur ne démarre pas », « qui utilise l'émulateur ? ». Not for host-side widget tests or PNG snapshots (ux-ui)."
effort: low
---

# AnKi on a device — claim, launch, observe, release

Tests and the ux-ui snapshots render AnKi's widgets on the host. Only a device shows what people
get: colour emoji, Android's nonlinear 200 % text, the system bars, permission dialogs, alarms
and notifications, contacts, Firestore offline, real startup. This skill puts the app on a device
and brings back evidence: screenshots you open with Read, the UI tree, logs, the system's dumps.

Talk to the maintainer in French; commands, file names and commit messages stay in English.

## Devices

| | `Honor_Magic7_Pro` emulator — default | Maintainer's phone, on request |
|---|---|---|
| What | 427 × 933 dp at 480 dpi, Android 16, Google APIs, French, Europe/Paris; serial printed by `claim` | over USB: `adb devices`, then `DEVICE=<serial>` before each command |
| Allowed | everything below, `adb root` included | drive the app and vary display settings; never `time`, `contact` or a wipe |
| Best for | every check an agent runs | real performance, the camera (book scanner), MagicOS behaviour |

**Session.** Agents never type passwords or create accounts, anonymous ones included: ask the
maintainer to sign in on the emulator once; Firebase keeps the session on the device.

## One device, many sessions

Sessions (worktrees, both clones) share the one emulator through a queue in `device.sh`: a
device serves one session at a time, and every command is refused to a session that doesn't
hold it, so nobody's APK, theme or clock lands in another's screenshots.

- **`claim` first**, with the Bash `timeout: 600000`: it waits its turn (first come, first
  served), boots or repairs the emulator, undoes what a vanished session left varied, and prints
  the serial. Exit 75 means run it again, the place is kept: still queued after 5 min
  (« position N, tenu par … »), or the device came to you after a wait with the emulator off
  (the next call boots it, so a boot never runs past the Bash's 10 min).
- **`release` last**, after closing your run tab: it restores your settings and hands over.
  Forgotten, it blocks the others until the 15-min lease (renewed by each command) runs out.
- The hold belongs to the whole session: its sub-agents share it (same
  `CLAUDE_CODE_SESSION_ID`). A `claim` that answers « déjà à toi » means your session already
  held it: don't `release` then, the session that claimed does. Run one `device-runner` at a
  time per session. `status`: who holds, who waits. Internals: recipes §16.

## Where each command runs

Builds (`flutter run`, `scripts/build_and_deploy.ps1`, `flutter pub get`) go to the app's
**Terminal panel** with `run_in_terminal`: Gradle fails in Claude's own shells (Java can't open a
selector there), and the maintainer sees the tab. adb, the emulator and `device.sh` run from the
Bash tool. No Terminal panel: recipes §13.

## Workflow

1. **Claim.** `bash .claude/skills/device/scripts/device.sh claim` (see above). Phone: prefix
   every command, `claim` included, with `DEVICE=<serial>`.
2. **Launch** in the Terminal panel: `run_in_terminal` with
   `& '.\scripts\run.ps1' -Example -d <serial> --print-dtd` (secrets.example.json, dummy Google
   Books key: never the real secrets.json; Books lookups fail there, check them on the phone),
   titled « AnKi · <device> ». Poll `read_terminal` (`wait_for_output_ms: 60000`) until
   « Flutter run key commands », or until a Gradle or Dart error, which you fix first. The first
   build takes ≈ 5 min; your install replaces the previous session's build, as it should.
   - Your build is already installed, nothing to rebuild: `device.sh start`.
   - Release, for startup time and smoothness: `run_in_terminal` with
     `$env:ANDROID_SERIAL = '<serial>'; & '.\scripts\build_and_deploy.ps1' -Release -ConfigPath secrets.example.json`.
3. **Observe.** `look <name>` takes the screenshot (prints a Windows path, open it with Read) and
   lists each labelled element as `label | class | x,y`, in one call. `shot` and `ui` do each
   half; `logs`, `crash`, `alarms` and `notifs` give the system's side.
4. **Drive.** `tap <label>` waits up to 6 s for the label (exact first, else the first one
   containing it, case ignored), so taps during a transition aren't lost; when it fails it lists
   what is visible. `wait <label> [s]` waits for a screen. Also `tap <x> <y>`, `type`,
   `key back`, `scroll down`.
5. **Iterate.** After an edit, hot reload: the Dart MCP `hot_reload` (below), or ask the
   maintainer to press `r` in the tab. Hot restart (`R`) for provider wiring, `initState`,
   routes; a full relaunch (`stop_terminal_tab`, then step 2) for native code, plugins, the
   manifest or `pubspec.yaml`.
6. **Vary.** `theme dark`, `text 2.0`, `size compact` (360 × 640 dp), `motion off`, `net off`,
   `tz`, `time`, `perm`, `contact`. The first display, motion, network, clock or time-zone
   variation records the device's settings; `release` (or `reset`) puts them back. Permissions
   and contacts aren't recorded: undo them with `perm reset <permission>` and `contact clear`.
7. **Release.** Close the run tab (`stop_terminal_tab`, `close: true`), then `device.sh release`.
   Leave the emulator running: the next session uses it.
8. **Report** in French: device and build mode, what you checked with the screenshot paths, what
   you couldn't check (camera, phone-only behaviour, a flow behind sign-in), time spent queued.

**Boot fails?** `claim` already repairs the usual causes (recipes §1); if it still fails, read
`~/.android/anki-device/emulator.log`, `release` (others are waiting), say what the log shows,
and ask the maintainer before `-wipe-data` or closing an emulator Android Studio owns.

**Dart MCP** (`dart` server, recipes §14): `dtd` `listDtdUris`, `connect` to the run whose
« Workspace Root » is *your* checkout, then `hot_reload`, `hot_restart`, `get_runtime_errors`,
`widget_inspector` `get_widget_tree` (`summaryOnly: true`). Never launch through it (it drops
`--dart-define-from-file`). Not connected: ask the maintainer to press `r`.

## `device.sh`

`bash .claude/skills/device/scripts/device.sh <command>`; `help` lists everything. Target:
`$DEVICE`, else the only device, else the emulator.

| Need | Commands |
|---|---|
| Queue | `claim` · `release` · `status` |
| Device | `info` · `start` · `stop` (a force-stop also drops the app's alarms until it reopens) · `boot` (inside `claim`) |
| See | `look [name]` · `shot [name]` → `build/device/<name>.png` · `ui` · `wait <label> [s]` · `logs [n]` · `crash [n]` |
| Reminders | `alarms` (AlarmManager entries, plus the plugin's own schedule on debug builds) · `notifs` |
| Drive | `tap <label>` · `tap <x> <y>` · `type <ASCII text>` · `key back\|home\|enter\|tab\|del\|recents` · `scroll down\|up` |
| Vary | `theme dark\|light` · `text <scale>` · `size compact\|reset\|<W>x<H>` · `motion off\|on` · `net off\|on` · `tz <zone>` · `time +3d\|+2h\|+10m\|'YYYY-MM-DD HH:MM'\|auto` (emulator) |
| Permissions | `perm` (state) · `perm grant\|revoke\|reset notifications\|contacts\|camera` |
| Fixtures | `contact "<name>" YYYY-MM-DD` · `contact "<name>" --MM-DD` (unknown year) · `contact clear` (emulator) |
| Undo | `reset` (also done by `release`) |

`references/recipes.md`: the AVD and its repairs, the phone, logs, recordings, TalkBack, a
reminder end to end, permissions, contacts, fingerprint, release startup, the queue (§16), rarer
gotchas (§17).

## Gotchas

- Revoking a permission makes Android kill the app (« Lost connection to device »): relaunch.
- Reminders fire at 10:00 *device* time. The app's language comes from the profile, not Android.
- A theme switch while the app runs can leave dark status-bar icons on a dark screen: cold-start
  in dark mode before judging the bars. Measure startup in release only (debug is JIT).
- `type` is ASCII only. `ui` and `tap` see only what Flutter exposes to accessibility: an
  unlabelled element is invisible to them, an accessibility finding in itself. A tile's
  semantics merge into one label (« Camille Martin / 15 mars »): tap any part of it.

## Never

- Type a password, create an account, or accept terms or a consent on the maintainer's behalf.
- Touch the device without holding it (`claim`), or stop another session's run tab.
- Change the clock, write contacts, `pm clear`, uninstall or wipe anything on the phone: it is
  the maintainer's own. On the emulator, `pm clear com.github.nautiii.an_ki` and `-wipe-data`
  erase the session and local data: ask first.
- Read or print `secrets.json` or the app's secure storage (`FlutterSecureKeyStorage.xml`).
