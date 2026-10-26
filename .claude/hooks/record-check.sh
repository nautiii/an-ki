#!/usr/bin/env bash
# Hook SubagentStart, SubagentStop (verifier|reviewer) et PostToolUse
# (SubagentHandback) : lie le verdict d'un agent de contrôle à son état de départ.
# - verifier : empreinte de l'index ; reviewer : commit HEAD (`unborn` sans commit).
# - SubagentStart : note cet état dans `<gitdir>/anki-checks/start/<id>`.
# - SubagentStop / SubagentHandback : si le rapport se termine par le verdict
#   (verifier : VERDICT: VERT ; reviewer : VERDICT: OK ou BLOQUANT, une revue
#   terminée dont la session applique les remarques) ET que l'état n'a pas bougé,
#   écrit le marqueur vide `<gitdir>/anki-checks/<empreinte>.verifier` ou
#   `<gitdir>/anki-checks/head-<HEAD>.reviewer` que guard-git.sh exige avant un
#   commit. Sinon n'écrit rien (raison sur stderr).
# Ne bloque jamais : sortie 0 dans tous les cas.

input=$(cat)

# Valeur d'une clé de premier niveau du JSON (chaîne simple, sans échappement).
field() {
  printf '%s' "$input" |
    sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
    head -n 1
}

event=$(field hook_event_name)
agent_id=$(field agent_id)
agent=$(field agent_type)
cwd=$(field cwd | sed 's/\\\\/\\/g')
dir=${cwd:-${CLAUDE_PROJECT_DIR:-.}}

case "$agent" in
  verifier) token='VERDICT: VERT' ;;
  reviewer) token='VERDICT: (OK|BLOQUANT)' ;;
  *) exit 0 ;;
esac
# L'identifiant sert de nom de fichier : on refuse tout caractère douteux.
case "$agent_id" in
  '' | *[!A-Za-z0-9_-]*) exit 0 ;;
esac

# Empreinte de l'index (mode, blob et chemin de chaque entrée), sans verrou :
# un index identique donne la même empreinte.
tree=$(set -o pipefail; git -C "$dir" ls-files -s -z 2>/dev/null | git hash-object --stdin 2>/dev/null) || exit 0
gitdir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null) || exit 0
[ -n "$tree" ] && [ -n "$gitdir" ] || exit 0

# Le verifier se lie à l'empreinte de l'index ; le reviewer, qui ne passe
# qu'une fois par commit, au commit courant (`unborn` sur une branche sans commit).
if [ "$agent" = reviewer ]; then
  state=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || state=unborn
  [ -n "$state" ] || state=unborn
else
  state=$tree
fi

start_dir="$gitdir/anki-checks/start"
start_file="$start_dir/$agent_id"
# Ménage : marqueurs et empreintes de départ de plus de 14 jours.
find "$gitdir/anki-checks" -type f -mtime +14 -delete 2>/dev/null

if [ "$event" = SubagentStart ]; then
  mkdir -p "$start_dir" 2>/dev/null || exit 0
  printf '%s' "$state" > "$start_file"
  exit 0
fi

# Rapport de l'agent : message final (Stop) ou message remis (Handback).
if [ "$event" = SubagentStop ]; then
  key=last_assistant_message
else
  key=message
fi
report=$(printf '%s' "$input" |
  sed -nE 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"((\\.|[^"\\])*)".*/\1/p' |
  head -n 1)
# Le rapport doit se terminer par le jeton : suivi seulement de retours à la
# ligne échappés ou d'espaces.
if ! printf '%s' "$report" | grep -Eq -- "$token(\\\\n|\\\\r| )*\$"; then
  [ "$event" = SubagentStop ] && rm -f "$start_file"
  exit 0
fi

start_state=''
[ -f "$start_file" ] && start_state=$(cat "$start_file" 2>/dev/null)
[ "$event" = SubagentStop ] && rm -f "$start_file"

if [ -z "$start_state" ]; then
  echo "record-check : état de départ inconnu, verdict non enregistré." >&2
  exit 0
fi
if [ "$start_state" != "$state" ]; then
  echo "record-check : l'index (verifier) ou HEAD (reviewer) a changé depuis le démarrage de l'agent, verdict non enregistré." >&2
  exit 0
fi

mkdir -p "$gitdir/anki-checks" 2>/dev/null || exit 0
if [ "$agent" = reviewer ]; then
  : > "$gitdir/anki-checks/head-$state.reviewer"
else
  : > "$gitdir/anki-checks/$state.$agent"
fi
exit 0
