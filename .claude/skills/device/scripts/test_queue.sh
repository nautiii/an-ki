#!/usr/bin/env bash
# Auto-test du guichet de device.sh, sans appareil : un faux adb et un dossier
# d'état temporaire. Usage : bash .claude/skills/device/scripts/test_queue.sh
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/adb" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_LOG"
case "$*" in
  devices) printf 'List of devices attached\nphone-1\tdevice\n' ;;
  # Le relevé des réglages d'origine (save_baseline).
  *'echo "night='*)
    printf '%s\n' night=no font_scale=null size= density= animator_duration_scale=null \
      transition_animation_scale=null window_animation_scale=null airplane=0 auto_time=1 \
      timezone=Europe/Paris
    ;;
  *"uimode night "*) [ -z "${FAKE_RESET_FAILS:-}" ] || exit 1 ;; # la remise (cmd_reset)
esac
EOF
chmod +x "$tmp/adb"

# Attente courte : une file bloquée échoue vite au lieu de pendre 9 min.
export DEVICE_STATE_DIR=$tmp/state DEVICE_ADB=$tmp/adb FAKE_LOG=$tmp/adb.log DEVICE=phone-1 \
  DEVICE_CLAIM_WAIT=4
fails=0
# run <session> <commande…> : lance device.sh comme la session donnée, sortie dans $out, code dans $rc.
run() {
  local who=$1
  shift
  out=$(DEVICE_OWNER=$who DEVICE_LABEL="session $who" bash "$here/device.sh" "$@" 2>&1)
  rc=$?
}
check() { # <description> <condition…>
  local what=$1
  shift
  if "$@"; then echo "ok   $what"; else
    echo "FAIL $what — rc=$rc, sortie : $out"
    fails=$((fails + 1))
  fi
}
has() { grep -q -- "$1" <<<"$out"; }
slot=$DEVICE_STATE_DIR/phone-1

run test-A claim
check "un identifiant avec tirets garde sa place" test $rc -eq 0
run test-A release
run A claim
check "A prend le guichet libre" test $rc -eq 0
run A theme dark
check "A varie un réglage" test -f "$slot/baseline.env"
: >"$FAKE_LOG"
run A claim
check "un second claim de la même session ne remet rien" eval '[ $rc -eq 0 ] && has "déjà à toi" && [ -f "$slot/baseline.env" ] && ! grep -q "uimode night " "$FAKE_LOG"'
run B key back
check "B est refusé tant que A tient l'appareil" eval '[ $rc -ne 0 ] && has "tenu par session A"'
run B status
check "status montre le détenteur" has "tenu par session A"
DEVICE_CLAIM_WAIT=1 run B claim
check "B attend, premier de la file" eval '[ $rc -eq 75 ] && has "position 1 sur 1"'
DEVICE_CLAIM_WAIT=1 run C claim
check "C attend derrière B" eval '[ $rc -eq 75 ] && has "position 2 sur 2"'
FAKE_RESET_FAILS=1 run A release
check "une remise ratée libère mais garde le relevé" eval '[ $rc -eq 0 ] && [ ! -d "$slot/held" ] && [ -f "$slot/baseline.env" ]'
mkdir "$slot/held" && printf 'A\n' >"$slot/held/owner" # A reprend la main pour la suite
: >"$FAKE_LOG"
run A release
check "release remet les réglages de A" eval '[ $rc -eq 0 ] && [ ! -f "$slot/baseline.env" ] && grep -q "uimode night" "$FAKE_LOG"'
DEVICE_CLAIM_WAIT=1 run C claim
check "C ne double pas B une fois libre" test $rc -eq 75
run B claim
check "B prend son tour" test $rc -eq 0
run B release
run C claim
check "puis C" test $rc -eq 0
run C theme dark
# C part sans release : son bail expire, D reprend la main et remet ses réglages.
touch -d '-20 minutes' "$slot/held/owner"
: >"$FAKE_LOG"
run D claim
check "D reprend un bail expiré et remet les réglages" eval '[ $rc -eq 0 ] && has "bail expiré" && grep -q "uimode night" "$FAKE_LOG"'
run C key back
check "C a perdu la main" test $rc -ne 0
run D release
# Une session partie de la file ne bloque pas les suivantes.
printf 'session E\n' >"$slot/queue/1000000000000000000-E"
touch -d '-5 minutes' "$slot/queue/1000000000000000000-E"
run F claim
check "un ticket abandonné est ignoré" test $rc -eq 0
run F release
# Une prise interrompue (held/ sans owner) depuis plus de 30 s est reprise.
mkdir "$slot/held" && touch -d '-1 minute' "$slot/held"
run H claim
check "une prise interrompue est reprise" eval '[ $rc -eq 0 ] && [ "$(cat "$slot/held/owner")" = H ]'
run H release
run G release
check "release sans guichet ne casse rien" eval '[ $rc -eq 0 ] && has "rien à libérer"'

[ $fails -eq 0 ] && echo "guichet : tout passe" || echo "guichet : $fails échec(s)"
exit $((fails > 0))
