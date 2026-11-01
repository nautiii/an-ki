#!/usr/bin/env bash
# Vérifications d'un commit sur l'index exact, lancées par le verifier depuis le
# dossier du dépôt : `static` (format des .dart indexés, flutter analyze, dart
# analyze) et `tests` (suite complète), l'une après l'autre ou en parallèle. Le
# script n'affiche que ce qui échoue.
# Une étape qui passe laisse <gitdir>/anki-checks/<empreinte>.<étape> ; dès que
# les deux sont là pour la même empreinte, il écrit <empreinte>.verifier, le
# marqueur que guard-git.sh exige avant un commit de code. Rien n'est écrit si la
# copie de travail diffère de l'index sur le code, ni si l'index bouge pendant
# l'étape : le marqueur prouve que ce qui sera commité a passé les vérifications,
# sans dépendre du message d'un agent.

step=$1
case "$step" in
  static) other=tests ;;
  tests) other=static ;;
  *)
    echo "usage : bash .claude/hooks/verify-index.sh static|tests" >&2
    exit 2
    ;;
esac
root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "pas de dépôt git ici : lancer depuis le dossier du dépôt" >&2
  exit 2
}
cd "$root" || exit 2
checks="$(git rev-parse --absolute-git-dir)/anki-checks"
logs="$checks/logs"
mkdir -p "$logs" || exit 2
find "$checks" -type f -mtime +14 -delete 2>/dev/null

# Chemins dont dépend le verdict (les mêmes que dans guard-git.sh).
code='^(lib/|test/|android/|ios/|pubspec\.(yaml|lock)$|analysis_options\.yaml$|l10n\.yaml$|firestore\.rules$|firestore\.indexes\.json$|firebase\.json$)|\.dart$|\.arb$'

# Empreinte de l'index (mode, blob et chemin de chaque entrée), comme guard-git.sh.
fingerprint() { git ls-files -s -z | git hash-object --stdin; }
# Code modifié hors de l'index ou non suivi : la copie testée ne serait pas ce qui
# est commité.
drift() {
  {
    git -c core.quotepath=off diff --name-only
    git -c core.quotepath=off ls-files --others --exclude-standard
  } | grep -E "$code"
}
# Lignes de problème d'une sortie (30 au plus), ou sa fin si aucune ne correspond
# (outil planté).
show() {
  local lines total
  lines=$(grep -E "$2" "$1")
  if [ -z "$lines" ]; then
    tail -n 15 "$1"
    return
  fi
  total=$(printf '%s\n' "$lines" | wc -l)
  printf '%s\n' "$lines" | head -n 30
  [ "$total" -gt 30 ] && echo "  + $((total - 30)) autres"
}

fp=$(fingerprint)
[ -n "$fp" ] || {
  echo "ÉCHEC : empreinte de l'index illisible."
  exit 2
}
dirty=$(drift)
if [ -n "$dirty" ]; then
  echo "ÉCHEC : la copie de travail diffère de l'index sur le code (indexer ou mettre de côté, puis relancer) :"
  printf '%s\n' "$dirty" | head -n 20 | sed 's/^/  - /'
  exit 1
fi
if [ ! -f .dart_tool/package_config.json ]; then
  echo "ÉCHEC : .dart_tool/package_config.json absent : pub get à lancer dans le Terminal."
  exit 1
fi

failed=''
if [ "$step" = static ]; then
  mapfile -d '' files < <(git diff --cached --name-only -z --diff-filter=d -- '*.dart')
  if [ "${#files[@]}" -eq 0 ]; then
    echo "- format : aucun .dart indexé"
  elif dart format --output=none --set-exit-if-changed "${files[@]}" >"$logs/format.log" 2>&1; then
    echo "- format : OK"
  else
    failed=1
    echo "- format : à formater"
    show "$logs/format.log" '^Changed ' | sed 's/^Changed /  - /'
  fi
  if flutter analyze --no-pub >"$logs/flutter-analyze.log" 2>&1; then
    echo "- flutter analyze : OK"
  else
    failed=1
    echo "- flutter analyze :"
    # flutter analyze sépare les champs par « - » sous Windows, « • » ailleurs.
    show "$logs/flutter-analyze.log" '^[[:space:]]*(error|warning|info) (•|-) '
  fi
  if dart analyze --fatal-infos >"$logs/dart-analyze.log" 2>&1; then
    echo "- dart analyze (riverpod_lint) : OK"
  else
    failed=1
    echo "- dart analyze (riverpod_lint) :"
    show "$logs/dart-analyze.log" '^[[:space:]]*(error|warning|info) - '
  fi
else
  flutter test --no-pub --reporter failures-only >"$logs/tests.log" 2>&1
  status=$?
  totals=$(grep -Eo '\+[0-9]+( ~[0-9]+)?( -[0-9]+)?' "$logs/tests.log" | tail -n 1)
  if [ "$status" -eq 0 ]; then
    echo "- tests : OK, ${totals:-?}"
  else
    failed=1
    echo "- tests : ${totals:-échec} — fin du journal (complet : $logs/tests.log) :"
    tail -n 120 "$logs/tests.log"
  fi
fi

if [ -n "$failed" ]; then
  echo "Étape $step : ÉCHEC sur l'index ${fp:0:7}, rien d'enregistré (journaux : $logs)."
  exit 1
fi
if [ "$(fingerprint)" != "$fp" ] || [ -n "$(drift)" ]; then
  echo "Étape $step : l'index ou la copie de travail a changé pendant l'étape, rien d'enregistré : relancer."
  exit 1
fi
: >"$checks/$fp.$step"
# Les deux étapes peuvent finir ensemble : chacune écrit son marqueur avant de
# chercher celui de l'autre, la dernière voit donc les deux.
if [ -f "$checks/$fp.$other" ]; then
  : >"$checks/$fp.verifier"
  echo "Index ${fp:0:7} vérifié (static et tests) : verdict enregistré pour le commit."
else
  echo "Étape $step : OK sur l'index ${fp:0:7} ; reste l'étape $other."
fi
exit 0
