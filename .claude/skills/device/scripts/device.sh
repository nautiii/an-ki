#!/usr/bin/env bash
# Pilote AnKi sur un appareil Android via adb : l'émulateur Honor_Magic7_Pro
# par défaut, le téléphone avec DEVICE=<numéro de série> (voir `adb devices`).
# Usage : device.sh <commande> [arguments] — `device.sh help` liste tout.
set -euo pipefail
# Git Bash convertit sinon /sdcard/… en C:/Program Files/Git/sdcard/… pour adb.exe.
export MSYS_NO_PATHCONV=1

AVD=Honor_Magic7_Pro
PKG=com.github.nautiii.an_ki
TZ_ID=Europe/Paris
SDK=${ANDROID_HOME:-${LOCALAPPDATA:-$HOME/AppData/Local}/Android/Sdk}
ADB=${DEVICE_ADB:-$SDK/platform-tools/adb.exe}
[ -x "$ADB" ] || ADB=adb
EMULATOR=$SDK/emulator/emulator.exe
TOP=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
OUT=$TOP/build/device
SERIAL=
KEY=

# Guichet : un appareil sert une session à la fois, les autres attendent leur
# tour. L'état est hors du dépôt pour être commun aux clones et aux worktrees.
STATE=${DEVICE_STATE_DIR:-$HOME/.android/anki-device}
LEASE=${DEVICE_LEASE:-900}            # s sans commande avant qu'une autre session reprenne la main
CLAIM_WAIT=${DEVICE_CLAIM_WAIT:-300}  # s d'attente par appel de claim : avec un démarrage, sous les 10 min du Bash
TICKET_TTL=120                        # s : un ticket non rafraîchi appartient à une session partie
# Les sous-agents partagent l'identifiant de leur session : ils agissent pour elle.
OWNER=${DEVICE_OWNER:-${CLAUDE_CODE_SESSION_ID:-$TOP}}
OWNER=${OWNER//[^A-Za-z0-9_.-]/_}
LABEL=${DEVICE_LABEL:-${CLAUDE_CODE_HOST_SESSION_ID:-$OWNER} · ${TOP##*/}}

usage() {
  cat <<'EOF'
device.sh <commande> — cible : $DEVICE, sinon l'unique appareil, sinon l'émulateur.

Guichet    claim (attend son tour, démarre l'émulateur, affiche la série) · release · status
           Toute autre commande exige d'avoir le guichet de l'appareil visé.
Appareil   boot · info · start · stop
Observer   shot [nom] · ui · look [nom] (capture + ui) · wait <libellé> [s] · logs [n] · crash [n]
           alarms · notifs
Piloter    tap <libellé> (attend qu'il apparaisse) | tap <x> <y> · type <texte ASCII>
           key <back|home|enter|tab|del|recents>
           scroll <down|up>
Varier     theme <dark|light> · text <échelle> · size <compact|reset|LxH> · motion <off|on>
           net <off|on> · tz <zone> · time <+3d|+2h|+10m|'AAAA-MM-JJ HH:MM'|auto>
           perm [grant|revoke|reset <notifications|contacts|camera>]
           contact "<nom>" <AAAA-MM-JJ|--MM-JJ> · contact clear      (émulateur seulement)
Remettre   reset — rétablit les réglages notés avant la première variation
EOF
}

say() { printf '%s\n' "$*" >&2; }
die() {
  say "device.sh : $*"
  exit 1
}

# Toujours sans stdin (adb le transmet à l'appareil) et borné dans le temps.
adb_() { timeout 90 "$ADB" "$@" </dev/null; }
dev() { adb_ -s "$SERIAL" "$@"; }
sh_() { dev shell "$@" | tr -d '\r'; }
is_emulator() { [[ $SERIAL == emulator-* ]]; }
app_pid() { sh_ pidof -s "$PKG" || true; }
win_path() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else printf '%s\n' "$1"; fi; }
# Met une valeur entre apostrophes pour le shell de l'appareil.
quote() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

devices() { adb_ devices | tr -d '\r' | awk 'NR > 1 && NF >= 2 { print $1, $2 }'; }

pick_serial() {
  if [ -n "${DEVICE:-}" ]; then
    SERIAL=$DEVICE
    return
  fi
  local ready
  ready=$(devices | awk '$2 == "device" { print $1 }')
  [ -n "$ready" ] || die "aucun appareil prêt : lance « device.sh claim » ou branche le téléphone"
  if [ "$(printf '%s\n' "$ready" | wc -l)" -eq 1 ]; then
    SERIAL=$ready
    return
  fi
  SERIAL=$(running_avd)
  [ -n "$SERIAL" ] || die "plusieurs appareils : précise DEVICE=<série> parmi $(printf '%s ' $ready)"
}

emulator_only() { is_emulator || die "$1 : émulateur seulement, jamais sur le téléphone"; }

# --- Guichet ----------------------------------------------------------------
# $STATE/<clé>/held/ : la session qui tient l'appareil (owner, info) ; la date
# de held/owner est celle de sa dernière commande. $STATE/<clé>/queue/ : un
# ticket par session en attente, nommé par son heure d'arrivée.

now() { date +%s; }
age() { echo $(($(now) - $(stat -c %Y "$1" 2>/dev/null || now))); }
# Durée lisible : secondes sous la minute, minutes au-delà.
dur() { if [ "$1" -lt 60 ]; then echo "$1 s"; else echo "$(($1 / 60)) min"; fi; }
# Clé du guichet : l'AVD pour l'émulateur, la série pour un téléphone.
target_key() {
  if [ -n "${DEVICE:-}" ] && [[ $DEVICE != emulator-* ]]; then KEY=${DEVICE//[^A-Za-z0-9_.-]/_}; else KEY=$AVD; fi
}
serial_key() { if is_emulator; then KEY=$AVD; else KEY=${SERIAL//[^A-Za-z0-9_.-]/_}; fi; }
slot() { printf '%s/%s' "$STATE" "$KEY"; }
holder() { cat "$(slot)/held/owner" 2>/dev/null || true; }
holder_label() { sed -n 1p "$(slot)/held/info" 2>/dev/null || echo "une session qui démarre"; }
holder_since() { sed -n 2p "$(slot)/held/info" 2>/dev/null || now; }

# Inactivité du détenteur ; un held/ sans owner est une prise interrompue.
holder_idle() {
  local h
  h=$(slot)/held
  if [ -f "$h/owner" ]; then age "$h/owner"; elif [ "$(age "$h")" -gt 30 ]; then echo "$LEASE"; else echo 0; fi
}

holder_line() {
  printf '%s, depuis %s (dernière commande il y a %s)' "$(holder_label)" \
    "$(dur $(($(now) - $(holder_since))))" "$(dur "$(holder_idle)")"
}

require_hold() {
  local h
  h=$(holder)
  if [ "$h" != "$OWNER" ]; then
    [ -d "$(slot)/held" ] || die "personne ne tient $KEY : lance d'abord « device.sh claim »"
    die "$KEY est tenu par $(holder_line) : lance « device.sh claim » pour prendre ton tour"
  fi
  touch "$(slot)/held/owner"
}

# Prend le guichet $KEY dans l'ordre d'arrivée. Code 75 si le tour n'est pas
# venu après $CLAIM_WAIT s : relancer garde la place dans la file.
acquire() {
  local sd q t head start pos
  sd=$(slot)
  start=$(now)
  mkdir -p "$sd/queue"
  if [ "$(holder)" = "$OWNER" ]; then
    touch "$sd/held/owner"
    say "déjà à toi : ta session tient $KEY (un sous-agent ne fait pas release)"
    return 0
  fi
  t=
  for q in "$sd/queue"/*; do
    q=${q##*/}
    [ "${q#*-}" != "$OWNER" ] || t=$q # <arrivée>-<session>, comparé exactement
  done
  [ -n "$t" ] || t=$(date +%s%N)-$OWNER
  while :; do
    printf '%s\n' "$LABEL" >"$sd/queue/$t"
    for q in "$sd/queue"/*; do
      [ "$q" = "$sd/queue/$t" ] || [ "$(age "$q")" -le "$TICKET_TTL" ] || rm -f "$q"
    done
    head=$(ls "$sd/queue" | sort | head -n 1)
    if [ "$head" = "$t" ]; then
      if [ -d "$sd/held" ] && [ "$(holder_idle)" -ge "$LEASE" ]; then
        # Un seul renommage réussit : deux sessions ne reprennent pas la main ensemble.
        say "reprise de $KEY : $(holder_line), bail expiré"
        mv "$sd/held" "$sd/stale.$$" 2>/dev/null && rm -rf "$sd/stale.$$"
      fi
      if mkdir "$sd/held" 2>/dev/null; then
        printf '%s\n' "$OWNER" >"$sd/held/owner"
        printf '%s\n%s\n%s\n' "$LABEL" "$(now)" "$TOP" >"$sd/held/info"
        rm -f "$sd/queue/$t"
        TOOK=1
        WAITED=$(($(now) - start))
        [ "$WAITED" -lt 5 ] || say "guichet $KEY pris après $(dur "$WAITED") d'attente"
        return 0
      fi
    fi
    if [ $(($(now) - start)) -ge "$CLAIM_WAIT" ]; then
      pos=$(ls "$sd/queue" | sort | grep -n -- "^$t\$" | cut -d: -f1)
      printf 'en attente : position %s sur %s — %s tient %s. Relance « device.sh claim » : la place est gardée.\n' \
        "$pos" "$(ls "$sd/queue" | wc -l)" "$(holder_line)" "$KEY"
      exit 75
    fi
    sleep 3
  done
}

cmd_claim() {
  TOOK= WAITED=0
  target_key
  acquire
  if [ "$KEY" = "$AVD" ]; then
    # Attente plus démarrage dépasseraient les 10 min du Bash, qui tuerait l'émulateur
    # en plein démarrage : le claim suivant, déjà détenteur, le démarre.
    if [ "$WAITED" -gt 30 ] && [ -z "$(running_avd)" ]; then
      echo "guichet $KEY pris, émulateur éteint : relance « device.sh claim » pour le démarrer."
      exit 75
    fi
    cmd_boot >/dev/null
  else
    SERIAL=$DEVICE
  fi
  # Réglages laissés par une session partie sans release, jamais ceux de sa propre session.
  if [ -n "$TOOK" ] && [ -f "$(baseline_file)" ]; then
    say "réglages laissés par la session précédente :"
    (cmd_reset) || say "remise ratée : lance « device.sh reset »"
  fi
  printf '%s\n' "$SERIAL"
}

cmd_release() {
  target_key
  if [ "$(holder)" != "$OWNER" ]; then
    say "tu ne tiens pas $KEY : rien à libérer"
    return 0
  fi
  if [ -f "$(baseline_file)" ]; then
    if [ "$KEY" = "$AVD" ]; then SERIAL=$(running_avd); else SERIAL=$DEVICE; fi
    # Un échec ne doit pas garder le guichet : le relevé reste et la prochaine prise le remet.
    if [ -z "$SERIAL" ] || ! (cmd_reset); then say "réglages non remis : la prochaine prise s'en charge"; fi
  fi
  local since
  since=$(holder_since)
  rm -rf "$(slot)/held"
  say "$KEY libéré après $(dur $(($(now) - since))) ; en attente : $(ls "$(slot)/queue" 2>/dev/null | wc -l)"
}

cmd_status() {
  local sd q
  [ -d "$STATE" ] || {
    echo "guichet vide"
    return
  }
  for sd in "$STATE"/*/; do
    KEY=$(basename "$sd")
    [ -d "$sd/queue" ] || [ -d "$sd/held" ] || continue
    if [ -d "$sd/held" ]; then
      printf '%s : tenu par %s%s\n' "$KEY" "$(holder_line)" "$([ "$(holder)" = "$OWNER" ] && echo ' — toi')"
    else
      printf '%s : libre\n' "$KEY"
    fi
    for q in $(ls "$sd/queue" 2>/dev/null | sort); do
      [ "$(age "$sd/queue/$q")" -le "$TICKET_TTL" ] && printf '  attend : %s\n' "$(cat "$sd/queue/$q")"
    done
  done
  return 0
}

# --- Appareil ---------------------------------------------------------------

# Série de l'émulateur $AVD vivant (même encore en démarrage), sinon rien : un
# émulateur arrêté reste quelques secondes « offline » dans `adb devices`.
running_avd() {
  local s
  for s in $(devices | awk '$1 ~ /^emulator-/ { print $1 }'); do
    if [ "$(adb_ -s "$s" emu avd name 2>/dev/null | tr -d '\r' | sed -n 1p)" = "$AVD" ]; then
      printf '%s' "$s"
      return
    fi
  done
}

# Le qemu de $AVD seulement : un autre AVD ouvert dans Android Studio ne compte pas.
qemu_alive() {
  powershell.exe -NoProfile -Command \
    "Get-CimInstance Win32_Process -Filter \"Name like 'qemu-system%'\" | ForEach-Object CommandLine" \
    </dev/null 2>/dev/null | tr -d '\r' | grep -qE -- "-avd $AVD( |\$)"
}

# Attend jusqu'à $1 s que l'AVD apparaisse dans adb ; échoue tout de suite si
# l'émulateur lancé ($2, facultatif) est déjà mort.
wait_avd() {
  local waited=0
  until SERIAL=$(running_avd) && [ -n "$SERIAL" ]; do
    if [ -n "${2:-}" ] && ! kill -0 "$2" 2>/dev/null; then
      die "l'émulateur s'est arrêté au lancement : $(tail -n 6 "$STATE/emulator.log" | tr -d '\r' | tr '\n' ' ')"
    fi
    [ $waited -lt "$1" ] || return 1
    sleep 2
    waited=$((waited + 2))
  done
}

wait_booted() {
  timeout "$1" "$ADB" -s "$SERIAL" wait-for-device shell \
    'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 1; done' </dev/null >/dev/null 2>&1
}

launch() { # [options de l'émulateur]
  local avd_dir=${ANDROID_AVD_HOME:-$HOME/.android/avd}/$AVD.avd pid
  # Sans qemu vivant, ces verrous viennent d'un émulateur planté et bloqueraient le lancement.
  qemu_alive || rm -rf "$avd_dir"/*.lock
  mkdir -p "$STATE"
  say "Démarrage de $AVD${*:+ $*} (≈ 20 s depuis l'instantané, ≈ 1 min à froid)…"
  # Détaché : l'émulateur survit au script ; son journal est dans le dossier du guichet.
  nohup "$EMULATOR" -avd "$AVD" -no-boot-anim -timezone "$TZ_ID" "$@" >"$STATE/emulator.log" 2>&1 &
  pid=$!
  wait_avd 60 "$pid" || die "l'émulateur n'apparaît pas, voir $(win_path "$STATE/emulator.log")"
}

cmd_boot() {
  local launched=
  SERIAL=$(running_avd)
  if [ -z "$SERIAL" ] && qemu_alive; then
    # Soit il finit de s'éteindre, soit il tourne (souvent lancé par Android Studio) et
    # adb l'a perdu : en relancer un second se heurterait à son verrou.
    local gone=0
    while [ $gone -lt 15 ] && qemu_alive; do
      sleep 3
      gone=$((gone + 3))
    done
  fi
  if [ -z "$SERIAL" ] && qemu_alive; then
    say "l'émulateur tourne sans être visible d'adb : reconnexion…"
    adb_ reconnect offline >/dev/null 2>&1 || true
    if ! wait_avd 10; then
      # Redémarrer le serveur adb coupe les flutter run de tous les appareils.
      if ls -d "$STATE"/*/held 2>/dev/null | grep -qvx "$(slot)/held"; then
        die "qemu tourne mais adb ne voit pas $AVD, et une autre session tient un appareil : demande au mainteneur"
      fi
      adb_ kill-server >/dev/null 2>&1 || true
      adb_ start-server >/dev/null 2>&1 || true
      wait_avd 30 || die "qemu tourne mais adb ne voit pas $AVD : ferme l'émulateur (Android Studio ou gestionnaire des tâches), puis relance claim"
    fi
  fi
  if [ -z "$SERIAL" ]; then
    launch
    launched=1
  fi
  # Pire cas, reprise à froid comprise : 60 + 120 + 30 + 60 + 240 s, sous les 10 min du Bash.
  if ! wait_booted 120; then
    # Un instantané abîmé bloque le démarrage : une seule reprise, à froid.
    [ -n "$launched" ] || die "$SERIAL n'a pas fini de démarrer en 120 s"
    say "pas démarré en 120 s : arrêt, puis démarrage à froid sans instantané…"
    dev emu kill >/dev/null 2>&1 || true
    local waited=0
    while [ -n "$(running_avd)" ] || qemu_alive; do
      [ $waited -lt 30 ] || die "l'émulateur bloqué ne s'arrête pas : ferme-le à la main"
      sleep 2
      waited=$((waited + 2))
    done
    launch -no-snapshot-load
    wait_booted 240 || die "$SERIAL n'a pas fini de démarrer, même à froid : voir $(win_path "$STATE/emulator.log")"
  fi
  sh_ wm dismiss-keyguard >/dev/null
  # Un démarrage à froid remet GMT : l'émulateur ne lit pas le fuseau de Windows.
  [ "$(sh_ getprop persist.sys.timezone)" = "$TZ_ID" ] || sh_ cmd alarm set-timezone "$TZ_ID"
  printf '%s\n' "$SERIAL"
}

cmd_info() {
  local pid
  pid=$(app_pid)
  sh_ 'echo "modèle     $(getprop ro.product.model), Android $(getprop ro.build.version.release) (API $(getprop ro.build.version.sdk))"
    echo "écran      $(wm size | tr "\n" " ")· $(wm density | tr "\n" " ")"
    echo "thème      $(cmd uimode night) · texte $(settings get system font_scale) · animations $(settings get global animator_duration_scale)"
    echo "réseau     mode avion $(settings get global airplane_mode_on)"
    echo "langue     $(settings get system system_locales) · $(date) · heure auto $(settings get global auto_time)"'
  if sh_ pm path "$PKG" | grep -q package:; then
    printf 'app        %s, %s\n' "$(sh_ dumpsys package "$PKG" | awk -F= '/versionName=/ && !v { v = $2 } END { print v }')" \
      "$([ -n "$pid" ] && echo "processus $pid" || echo "arrêtée")"
  else
    printf 'app        non installée\n'
  fi
  printf 'cible      %s%s\n' "$SERIAL" "$(is_emulator && printf ' (AVD %s)' "$(dev emu avd name | tr -d '\r' | sed -n 1p)")"
}

cmd_start() { sh_ am start -W -n "$PKG/.MainActivity" | grep -E 'Status|LaunchState|TotalTime' || true; }

cmd_stop() {
  sh_ am force-stop "$PKG"
  say "(un arrêt forcé efface aussi les alarmes de l'app jusqu'à sa prochaine ouverture)"
}

# --- Observer ---------------------------------------------------------------

cmd_shot() {
  local file=$OUT/${1:-shot-$(date +%H%M%S)}.png
  mkdir -p "$OUT"
  dev exec-out screencap -p >"$file"
  win_path "$file"
}

# Une ligne par élément libellé : « libellé | classe | x,y » (centre, en pixels).
ui_list() {
  mkdir -p "$OUT"
  dev exec-out uiautomator dump /dev/tty | tr -d '\r' | sed 's#UI hierch\?archy dumped to: /dev/tty##' >"$OUT/ui.xml"
  grep -q '<hierarchy' "$OUT/ui.xml" || die "dump impossible : $(head -c 200 "$OUT/ui.xml")"
  grep -o '<node [^>]*>' "$OUT/ui.xml" | awk '
    function attr(name,   s) {
      if (!match($0, " " name "=\"[^\"]*\"")) return ""
      s = substr($0, RSTART + length(name) + 3, RLENGTH - length(name) - 4)
      gsub(/&#10;/, " / ", s); gsub(/&quot;/, "\"", s); gsub(/&apos;/, "\047", s)
      gsub(/&lt;/, "<", s); gsub(/&gt;/, ">", s); gsub(/&amp;/, "\\&", s)
      return s
    }
    {
      label = attr("text"); if (label == "") label = attr("content-desc")
      if (label == "") label = attr("hint")
      if (label == "") next
      class = attr("class"); sub(/.*\./, "", class)
      b = attr("bounds"); gsub(/[^0-9]+/, " ", b); split(b, n, " ")   # x1 y1 x2 y2
      printf "%s | %s | %d,%d\n", label, class, (n[1] + n[3]) / 2, (n[2] + n[4]) / 2
    }'
}

cmd_ui() { ui_list; }

# Libellé exact d'abord, sinon le premier qui le contient (casse ignorée).
find_label() {
  ui_list 2>/dev/null | awk -F ' [|] ' -v w="$1" '
    BEGIN { w = tolower(w) }
    tolower($1) == w { print; found = 1; exit }
    first == "" && index(tolower($1), w) { first = $0 }
    END { if (!found && first != "") print first }'
}

await_label() { # <secondes> <libellé> : affiche « libellé | classe | x,y » dès qu'il est là
  local deadline hit
  deadline=$(($(now) + $1))
  while :; do
    hit=$(find_label "$2" || true)
    [ -z "$hit" ] || {
      printf '%s\n' "$hit"
      return 0
    }
    [ "$(now)" -lt "$deadline" ] || return 1
    sleep 1
  done
}

visible_labels() { ui_list 2>/dev/null | cut -d '|' -f 1 | sed 's/ *$//' | head -n 20 | paste -sd ';' - || true; }

cmd_wait() {
  [ -n "${1:-}" ] || die "wait <libellé> [secondes]"
  await_label "${2:-10}" "$1" || die "« $1 » n'est pas apparu en ${2:-10} s. Visibles : $(visible_labels)"
}

cmd_look() {
  cmd_shot "${1:-}"
  ui_list
}

cmd_logs() {
  local n=${1:-60} pid
  pid=$(app_pid)
  if [ -n "$pid" ]; then
    dev logcat -d -v time --pid="$pid" '*:W' flutter:I | tr -d '\r' | tail -n "$n"
  else
    say "(app arrêtée : derniers messages flutter et plantages)"
    dev logcat -d -v time -s flutter:I AndroidRuntime:E | tr -d '\r' | tail -n "$n"
  fi
}

cmd_crash() { dev logcat -d -b crash -v time | tr -d '\r' | tail -n "${1:-60}"; }

cmd_alarms() {
  sh_ dumpsys alarm | awk -v p="$PKG" '
    /^    [A-Z_]+ #[0-9]+: Alarm\{/ { mine = index($0, p) > 0; next }
    mine && /origWhen=/ { sub(/^ +type=/, ""); sub(/ window=.*/, ""); print; n++; mine = 0 }
    END { printf "%d alarme(s) AlarmManager pour %s\n", n, p }'
  # Build debug : le plugin garde aussi la liste qu'il a planifiée (titres, dates).
  local cache
  cache=$(sh_ run-as "$PKG" cat shared_prefs/notification_plugin_cache.xml 2>/dev/null || true)
  if grep -q scheduled_notifications <<<"$cache"; then
    sed -n 's/.*name="scheduled_notifications">\(.*\)<\/string>.*/\1/p' <<<"$cache" |
      sed 's/&quot;/"/g; s/},{/}\n{/g' | cut -c1-400
  fi
}

cmd_notifs() {
  sh_ dumpsys notification --noredact | awk -v p="$PKG" '
    /NotificationRecord\(/ {
      mine = index($0, "pkg=" p " ") > 0
      if (mine) { n++; match($0, /id=-?[0-9]+/); print "#" n " " substr($0, RSTART, RLENGTH) }
      next
    }
    mine && /android\.(title|text|bigText)=/ { sub(/^ +/, "   "); print }
    END { if (!n) print "aucune notification affichée pour " p }'
}

# --- Piloter ----------------------------------------------------------------

cmd_tap() {
  if [ $# -eq 2 ] && [[ $1 =~ ^[0-9]+$ && $2 =~ ^[0-9]+$ ]]; then
    dev shell input tap "$1" "$2"
    return
  fi
  [ $# -ge 1 ] || die "tap <libellé> | tap <x> <y>"
  local hit xy
  # Attendre le libellé absorbe les transitions : un tap envoyé pendant l'une d'elles se perd.
  hit=$(await_label 6 "$*") || die "« $* » introuvable à l'écran en 6 s. Visibles : $(visible_labels)"
  xy=${hit##* | }
  dev shell input tap "${xy%,*}" "${xy#*,}"
  say "tap $xy — ${hit%% | *}"
}

cmd_type() {
  local text=$*
  if printf '%s' "$text" | LC_ALL=C grep -q '[^ -~]'; then
    die "input text ne gère que l'ASCII : un accent se tape sur l'appareil"
  fi
  # `input text` lit %s comme une espace.
  dev shell input text "$(quote "${text// /%s}")"
}

cmd_key() {
  local code
  case ${1:-} in
    back) code=KEYCODE_BACK ;;
    home) code=KEYCODE_HOME ;;
    enter) code=KEYCODE_ENTER ;;
    tab) code=KEYCODE_TAB ;;
    del) code=KEYCODE_DEL ;;
    recents) code=KEYCODE_APP_SWITCH ;;
    KEYCODE_* | [0-9]*) code=$1 ;;
    *) die "key back|home|enter|tab|del|recents|KEYCODE_…" ;;
  esac
  dev shell input keyevent "$code"
}

cmd_scroll() {
  local size w h
  size=$(sh_ wm size | awk -F ': ' '/Override/ { o = $2 } /Physical/ { p = $2 } END { print (o ? o : p) }')
  w=${size%x*}
  h=${size#*x}
  case ${1:-down} in
    down) dev shell input swipe $((w / 2)) $((h * 3 / 4)) $((w / 2)) $((h / 4)) 300 ;;
    up) dev shell input swipe $((w / 2)) $((h / 4)) $((w / 2)) $((h * 3 / 4)) 300 ;;
    *) die "scroll down|up" ;;
  esac
}

# --- Varier, puis remettre ------------------------------------------------------

# Dans le guichet, pour qu'une session qui reprend la main remette ce qu'une autre a varié.
baseline_file() { printf '%s/baseline.env' "$(slot)"; }

# Note les réglages d'origine avant la première variation, pour `reset`.
save_baseline() {
  local file
  file=$(baseline_file)
  [ -f "$file" ] && return
  mkdir -p "$OUT"
  sh_ 'echo "night=$(cmd uimode night | sed "s/.*: //")"
    echo "font_scale=$(settings get system font_scale)"
    echo "size=$(wm size | sed -n "s/^Override size: //p")"
    echo "density=$(wm density | sed -n "s/^Override density: //p")"
    for k in animator_duration_scale transition_animation_scale window_animation_scale; do
      echo "$k=$(settings get global $k)"
    done
    echo "airplane=$(settings get global airplane_mode_on)"
    echo "auto_time=$(settings get global auto_time)"
    echo "timezone=$(getprop persist.sys.timezone)"' >"$file.tmp"
  # Un relevé partiel ferait échouer toutes les remises suivantes.
  grep -q '^timezone=' "$file.tmp" || die "relevé des réglages impossible : $(head -c 200 "$file.tmp")"
  mv "$file.tmp" "$file"
}

put_or_delete() { # <namespace> <clé> <valeur> : « null » = valeur par défaut
  if [ "$3" = null ] || [ -z "$3" ]; then printf 'settings delete %s %s;' "$1" "$2"; else printf 'settings put %s %s %s;' "$1" "$2" "$3"; fi
}

cmd_reset() {
  local file night font_scale size density animator_duration_scale transition_animation_scale \
    window_animation_scale airplane auto_time timezone script
  file=$(baseline_file)
  if [ -f "$file" ]; then
    # shellcheck disable=SC1090 # fichier écrit par save_baseline
    . "$file"
  elif is_emulator; then
    night=no font_scale=null size= density= airplane=0 auto_time=1 timezone=$TZ_ID
    animator_duration_scale=null transition_animation_scale=null window_animation_scale=null
  else
    say "rien à restaurer pour $SERIAL"
    return
  fi
  script="cmd uimode night $night >/dev/null; $(put_or_delete system font_scale "$font_scale")"
  script+=" wm size ${size:-reset}; wm density ${density:-reset};"
  for k in animator_duration_scale transition_animation_scale window_animation_scale; do
    script+=" $(put_or_delete global "$k" "${!k}")"
  done
  script+=" cmd connectivity airplane-mode $([ "$airplane" = 1 ] && echo enable || echo disable);"
  script+=" $(put_or_delete global auto_time "$auto_time") cmd alarm set-timezone $timezone"
  # Le relevé ne part qu'une fois remis, sinon la session suivante prendrait ces réglages pour l'origine.
  sh_ "$script" >/dev/null || return 1
  rm -f "$file"
  say "réglages d'origine rétablis sur $SERIAL"
}

cmd_theme() {
  save_baseline
  case ${1:-} in
    dark) sh_ cmd uimode night yes ;;
    light) sh_ cmd uimode night no ;;
    *) die "theme dark|light" ;;
  esac
}

cmd_text() {
  [[ ${1:-} =~ ^[0-9]+(\.[0-9]+)?$ ]] || die "text <échelle> : 1.0, 1.3, 2.0…"
  save_baseline
  sh_ settings put system font_scale "$1"
}

cmd_size() {
  save_baseline
  case ${1:-} in
    compact) sh_ wm size 1080x1920 ;; # 360 × 640 dp à 480 dpi
    reset) sh_ 'wm size reset; wm density reset' ;;
    [0-9]*x[0-9]*) sh_ wm size "$1" ;;
    *) die "size compact|reset|<largeur>x<hauteur>" ;;
  esac
}

cmd_motion() {
  local v
  case ${1:-} in
    off) v=0 ;;
    on) v=1 ;;
    *) die "motion off|on" ;;
  esac
  save_baseline
  sh_ "for k in animator_duration_scale transition_animation_scale window_animation_scale; do settings put global \$k $v; done"
}

cmd_net() {
  save_baseline
  case ${1:-} in
    off) sh_ cmd connectivity airplane-mode enable ;;
    on) sh_ cmd connectivity airplane-mode disable ;;
    *) die "net off|on" ;;
  esac
}

cmd_tz() {
  [ -n "${1:-}" ] || die "tz <zone>, par exemple Europe/Paris"
  save_baseline
  sh_ cmd alarm set-timezone "$1"
  sh_ date
}

cmd_time() {
  emulator_only time
  local arg=${1:-} now target
  if [ "$arg" = auto ]; then
    sh_ settings put global auto_time 1
    sh_ date
    return
  fi
  now=$(sh_ date +%s)
  case $arg in
    +*d) target=$((now + ${arg:1:-1} * 86400)) ;;
    +*h) target=$((now + ${arg:1:-1} * 3600)) ;;
    +*m) target=$((now + ${arg:1:-1} * 60)) ;;
    [0-9][0-9][0-9][0-9]-*) target=$(sh_ date -d "$(quote "$arg")" +%s) ;;
    *) die "time +3d | +2h | +10m | 'AAAA-MM-JJ HH:MM' | auto" ;;
  esac
  save_baseline
  sh_ "settings put global auto_time 0; cmd alarm set-time $((target * 1000)); date"
}

cmd_perm() {
  local perm
  if [ $# -eq 0 ]; then
    sh_ dumpsys package "$PKG" | grep -E 'permission\.(POST_NOTIFICATIONS|READ_CONTACTS|CAMERA): granted' |
      sed 's/^ *android.permission.//; s/, flags=.*//'
    return
  fi
  case ${2:-} in
    notifications) perm=android.permission.POST_NOTIFICATIONS ;;
    contacts) perm=android.permission.READ_CONTACTS ;;
    camera) perm=android.permission.CAMERA ;;
    *) die "perm grant|revoke|reset notifications|contacts|camera" ;;
  esac
  case $1 in
    grant) sh_ pm grant "$PKG" "$perm" ;;
    revoke)
      sh_ pm revoke "$PKG" "$perm"
      say "(retirer une permission tue l'app : flutter run perd la connexion)"
      ;;
    reset)
      sh_ pm revoke "$PKG" "$perm"
      sh_ pm clear-permission-flags "$PKG" "$perm" user-set user-fixed
      say "(l'app redemandera la permission ; si elle tournait, Android l'a tuée)"
      ;;
    *) die "perm grant|revoke|reset …" ;;
  esac
}

cmd_contact() {
  emulator_only contact
  if [ "${1:-}" = clear ]; then
    sh_ content delete --uri content://com.android.contacts/raw_contacts --where "$(quote 'account_type IS NULL')"
    say "contacts locaux de l'émulateur supprimés"
    return
  fi
  local name=${1:-} date=${2:-} rid
  [[ -n $name && $date =~ ^(--|[0-9]{4}-)[0-9]{2}-[0-9]{2}$ ]] ||
    die 'contact "<nom>" <AAAA-MM-JJ|--MM-JJ>  (--MM-JJ : année inconnue)'
  sh_ content insert --uri content://com.android.contacts/raw_contacts \
    --bind account_type:n: --bind account_name:n:
  rid=$(sh_ content query --uri content://com.android.contacts/raw_contacts \
    --projection _id --sort "$(quote '_id DESC')" | sed -n '1s/.*_id=\([0-9]*\).*/\1/p')
  [ -n "$rid" ] || die "contact non créé"
  sh_ content insert --uri content://com.android.contacts/data --bind "raw_contact_id:i:$rid" \
    --bind mimetype:s:vnd.android.cursor.item/name --bind "$(quote "data1:s:$name")"
  sh_ content insert --uri content://com.android.contacts/data --bind "raw_contact_id:i:$rid" \
    --bind mimetype:s:vnd.android.cursor.item/contact_event --bind "data1:s:$date" --bind data2:i:3
  say "contact $rid : $name, anniversaire $date"
}

main() {
  local cmd=${1:-help}
  shift || true
  case $cmd in
    help | -h | --help) usage ;;
    claim | release | status) "cmd_$cmd" "$@" ;;
    boot)
      target_key
      require_hold
      cmd_boot "$@"
      ;;
    *)
      declare -F "cmd_$cmd" >/dev/null || die "commande inconnue : $cmd (device.sh help)"
      pick_serial
      serial_key
      require_hold
      "cmd_$cmd" "$@"
      ;;
  esac
}

main "$@"
