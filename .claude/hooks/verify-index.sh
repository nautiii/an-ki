#!/usr/bin/env bash
# Vérifications d'AnKi, lancées par la session principale elle-même (pas
# d'agent) depuis le dossier du dépôt : `static` (normes du projet, l10n, format
# des .dart modifiés, dart analyze), `tests` (suite complète, test
# d'architecture compris), ou les deux en parallèle sans argument. Le script
# n'affiche que ce qui échoue, en peu de lignes.
#
# L'état du dépôt décide de ce qui est vérifié :
# - index : la copie de travail ne diffère pas de l'index sur le code. Une étape
#   qui passe laisse <gitdir>/anki-checks/<empreinte>.<étape> ; dès que les deux
#   sont là pour la même empreinte, <empreinte>.verifier (nom d'avant la
#   suppression de l'agent, gardé pour les branches plus anciennes), le verdict
#   que guard-git.sh exige avant un commit de code. Rien n'est écrit si l'index ou
#   la copie de travail bouge pendant les vérifications : le verdict prouve que
#   ce qui sera commité est passé, sans dépendre du message d'un agent.
# - copie de travail : du code diffère de l'index (travail en cours, fin de
#   session sans commit) : mêmes vérifications sur la copie de travail, sans
#   verdict.

case "${1:-all}" in
  static | tests | all) step=${1:-all} ;;
  *)
    echo "usage : bash .claude/hooks/verify-index.sh [static|tests]" >&2
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
# Fichiers écrits par flutter gen-l10n.
generated='lib/l10n/app_localizations*.dart'

g() { git -c core.quotepath=off "$@"; }
# Empreinte de l'index (mode, blob et chemin de chaque entrée), comme guard-git.sh.
fingerprint() { git ls-files -s -z | git hash-object --stdin; }
# Code modifié hors de l'index ou non suivi : la copie vérifiée ne serait pas ce
# qui est commité.
drift() {
  {
    g diff --name-only
    g ls-files --others --exclude-standard
  } | grep -E "$code"
}
# Chemins modifiés depuis HEAD : index, copie de travail, non suivis.
changed() {
  {
    g diff HEAD --name-only --no-renames
    g diff --cached --name-only --no-renames
    g ls-files --others --exclude-standard
  } | sort -u
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

# Normes d'AGENTS.md qu'aucun analyseur ne voit, jugées sur les lignes ajoutées
# depuis HEAD (le code existant n'est pas rejugé). Une ligne qui porte
# « norme: exception » est sautée : le reviewer juge l'exception.
read -r -d '' norms_awk <<'AWK'
BEGIN { FS = "\t" }
function report(msg) {
  if (++found <= 30) printf "  - %s:%s — %s\n", path, line, msg
}
{
  path = $1
  line = $2
  text = $0
  sub(/^[^\t]*\t[^\t]*\t/, "", text)
  if (text ~ /norme: exception/) next
  code = text
  sub(/^[ \t]+/, "", code)
  if (code ~ /^(\/\/|\/\*|\*)/) next
  sub(/[ \t]+\/\/.*$/, "", code)
  if (path == "pubspec.yaml") {
    if (code ~ /^(sdk|flutter)[ \t]*:/) next
    if (code ~ /^[A-Za-z0-9_]+[ \t]*:[ \t]*["']?(\^|>|<|any([ \t"']|$))/)
      report("version non épinglée : version exacte, sans ^ ni plage")
    if (code ~ /^(freezed|freezed_annotation|json_serializable|json_annotation|riverpod_generator|riverpod_annotation|build_runner)[ \t]*:/)
      report("génération de code interdite (modèles et providers écrits à la main)")
    next
  }
  if (path !~ /\.dart$/) next
  if (code ~ /StateNotifier|riverpod\/legacy\.dart/)
    report("StateNotifier et legacy.dart interdits : Notifier de Riverpod 3")
  if (path !~ /^lib\//) next
  if (path != "lib/core/providers/clock_provider.dart" && code ~ /DateTime\.now([^A-Za-z0-9_]|$)/)
    report("DateTime.now hors de clockProvider : lire l'heure par clockProvider")
  if (path !~ /^lib\/core\/theme\// &&
      (code ~ /(^|[^A-Za-z0-9_.])(Color\(0x|Color\.from(ARGB|RGBO)\()/ ||
       (code ~ /(^|[^A-Za-z0-9_.])Colors\.[a-z]/ && code !~ /Colors\.transparent/)))
    report("couleur en dur : jeton du thème (lib/core/theme)")
  if (path !~ /^lib\/(core\/providers\/|main\.dart$)/ && code ~ /(FirebaseFirestore|FirebaseAuth)\.instance/)
    report("singleton Firebase hors de core/providers : passer par son provider")
  s = code
  gsub(/[$][{][^}]*[}]/, "", s)
  gsub(/[$][A-Za-z_][A-Za-z0-9_]*/, "", s)
  # Text( peut finir la ligne précédente : le formateur passe l'argument à la ligne.
  after_text = (path == open_path && line == open_line + 1)
  if (s ~ /(^|[^A-Za-z0-9_])Text\([ \t]*r?["'][^"']*[A-Za-z]/ ||
      (after_text && s ~ /^r?["'][^"']*[A-Za-z]/) ||
      s ~ /(tooltip|labelText|hintText|helperText|errorText|semanticLabel|semanticsLabel)[ \t]*:[ \t]*r?["'][^"']*[A-Za-z]/)
    report("texte en dur : clé ARB (FR + EN), lue par context.l10n")
  if (code ~ /(^|[^A-Za-z0-9_])Text\([ \t]*$/) {
    open_path = path
    open_line = line
  }
}
END {
  if (found > 30) printf "  + %d autres\n", found - 30
  exit found > 0
}
AWK

# Lignes ajoutées depuis HEAD, au format chemin<TAB>numéro<TAB>texte ; un
# fichier non suivi compte en entier.
added_lines() {
  g diff HEAD -U0 --no-color --no-ext-diff --no-renames -- "$@" |
    awk '
      /^\+\+\+ / { f = substr($0, 7); next }
      /^@@/ { split($3, a, ","); n = substr(a[1], 2) + 0; next }
      /^\+/ { print f "\t" n "\t" substr($0, 2); n++ }
    '
  g ls-files --others --exclude-standard -- "$@" | while IFS= read -r f; do
    awk -v f="$f" '{ print f "\t" NR "\t" $0 }' "$f"
  done
}

check_norms() {
  local secrets status=0
  secrets=$(g diff --cached --name-only | grep -Ei '(^|/)(secrets\.json|key\.properties|\.env)$|\.(jks|keystore)$')
  if [ -n "$secrets" ]; then
    printf '  - secret indexé, à retirer de l’index : %s\n' $secrets
    status=1
  fi
  added_lines '*.dart' pubspec.yaml ":(exclude)$generated" | awk "$norms_awk" || status=1
  return $status
}

# ARB : mêmes clés dans chaque langue que dans le modèle français, et fichiers
# générés à jour (gen-l10n relancé ici quand lib/l10n a changé).
arb_keys() { grep -oE '^  "[^"@][^"]*"' "$1" | tr -d ' "' | sort -u; }
check_l10n() {
  local template=lib/l10n/intl_fr.arb arb missing extra before after status=0
  printf '%s\n' "$changed_paths" | grep -q '^lib/l10n/' || return 0
  for arb in lib/l10n/intl_*.arb; do
    [ "$arb" = "$template" ] && continue
    missing=$(comm -23 <(arb_keys "$template") <(arb_keys "$arb") | head -n 10 | paste -sd ' ')
    extra=$(comm -13 <(arb_keys "$template") <(arb_keys "$arb") | head -n 10 | paste -sd ' ')
    [ -n "$missing" ] && echo "  - clés absentes de $arb : $missing" && status=1
    [ -n "$extra" ] && echo "  - clés de $arb absentes du modèle $template : $extra" && status=1
  done
  # shellcheck disable=SC2086 # le motif des fichiers générés doit s'étendre
  before=$(cat $generated 2>/dev/null | git hash-object --stdin)
  if ! flutter gen-l10n >"$logs/gen-l10n.log" 2>&1; then
    echo "  - flutter gen-l10n échoue :"
    tail -n 10 "$logs/gen-l10n.log" | sed 's/^/    /'
    return 1
  fi
  # shellcheck disable=SC2086
  after=$(cat $generated 2>/dev/null | git hash-object --stdin)
  if [ "$before" != "$after" ]; then
    if [ "$mode" = index ]; then
      echo "  - flutter gen-l10n n'avait pas été relancé : fichiers générés mis à jour, à indexer avec les ARB"
      status=1
    else
      echo "  - note : flutter gen-l10n relancé, fichiers générés mis à jour (à indexer avec les ARB)"
    fi
  fi
  return $status
}

check_format() {
  local files=() f
  while IFS= read -r f; do
    [ -f "$f" ] && files+=("$f")
  done < <(printf '%s\n' "$changed_paths" | grep -E '\.dart$')
  [ "${#files[@]}" -eq 0 ] && return 0
  dart format --output=none --set-exit-if-changed "${files[@]}" >"$logs/format.log" 2>&1 && return 0
  show "$logs/format.log" '^Changed ' | sed 's/^Changed /  - à formater : /'
  return 1
}

# dart analyze seul : il rend les mêmes diagnostics que flutter analyze (mêmes
# options, même moteur, comparés le 2026-11-06 sur erreurs, warnings et lints
# Flutter), plus ceux du plugin riverpod_lint que flutter analyze ne lance pas.
check_analyze() {
  dart analyze --fatal-infos >"$logs/analyze.log" 2>&1 && return 0
  show "$logs/analyze.log" '^[[:space:]]*(error|warning|info) - '
  return 1
}

check_tests() {
  local status totals
  flutter test --no-pub --reporter failures-only >"$logs/tests.log" 2>&1
  status=$?
  totals=$(grep -Eo '\+[0-9]+( ~[0-9]+)?( -[0-9]+)?' "$logs/tests.log" | tail -n 1)
  printf '%s\n' "${totals:-?}" >"$logs/tests.totals"
  [ "$status" -eq 0 ] && return 0
  echo "  ${totals:-échec} — journal complet : $logs/tests.log"
  # Cadres de pile du SDK et des paquets de test retirés : restent les erreurs
  # et les cadres du projet.
  grep -Ev '^(package:(flutter|flutter_test|test_api|matcher|stack_trace|fake_async|async|test)/|dart:|<asynchronous suspension>|#[0-9]+[[:space:]].*\((package:(flutter|flutter_test|test_api|matcher|stack_trace|fake_async|async)/|dart:))' \
    "$logs/tests.log" | tail -n 80 | sed 's/^/    /'
  return 1
}

fp=$(fingerprint)
[ -n "$fp" ] || {
  echo "ÉCHEC : empreinte de l'index illisible."
  exit 2
}
dirty=$(drift)
if [ -n "$dirty" ]; then
  mode=copie
  echo "Copie de travail ≠ index sur le code ($(printf '%s\n' "$dirty" | head -n 3 | paste -sd ' ')$([ "$(printf '%s\n' "$dirty" | wc -l)" -gt 3 ] && echo ' …')) : vérifiée telle quelle, sans verdict."
else
  mode=index
fi
if [ ! -f .dart_tool/package_config.json ]; then
  echo "ÉCHEC : .dart_tool/package_config.json absent : pub get à lancer dans le Terminal."
  exit 1
fi
changed_paths=$(changed)

case "$step" in
  static) names='l10n norms format analyze' ;;
  tests) names='tests' ;;
  all) names='l10n norms format analyze tests' ;;
esac
for n in $names; do rm -f "$logs/$n.out" "$logs/$n.status"; done
# run <nom> : check_<nom>, sortie dans <nom>.out, statut dans <nom>.status.
run() {
  "check_$1" >"$logs/$1.out" 2>&1
  echo $? >"$logs/$1.status"
}
# gen-l10n d'abord : il réécrit des fichiers que l'analyse et les tests lisent.
if [ "$step" != tests ]; then
  run l10n
  run norms
  run format
fi
case "$step" in
  all)
    run tests &
    run analyze
    wait
    ;;
  static) run analyze ;;
  tests) run tests ;;
esac

label() {
  case "$1" in
    norms) echo normes ;;
    analyze) echo "dart analyze" ;;
    tests) echo "tests $(cat "$logs/tests.totals" 2>/dev/null)" ;;
    *) echo "$1" ;;
  esac
}
passed='' failed=''
for n in $names; do
  if [ "$(cat "$logs/$n.status" 2>/dev/null)" = 0 ]; then
    passed="${passed:+$passed, }$(label "$n")"
  else
    failed="${failed:+$failed }$n"
  fi
done
if [ -n "$failed" ]; then
  echo "ÉCHEC — $(for n in $failed; do label "$n"; done | paste -sd ',' | sed 's/,/, /g')${passed:+ (OK : $passed)}"
  for n in $failed; do
    echo "- $(label "$n") :"
    cat "$logs/$n.out"
  done
  [ "$mode" = index ] && echo "Index ${fp:0:7} : rien d'enregistré (journaux : $logs)."
  exit 1
fi
echo "OK — $passed"
# Notes des étapes passées (gen-l10n relancé sur la copie de travail).
for n in $names; do
  [ -s "$logs/$n.out" ] && cat "$logs/$n.out"
done
if [ "$mode" = copie ]; then
  echo "Copie de travail vérifiée, aucun verdict : avant un commit, indexer le changement et relancer."
  exit 0
fi
if [ "$(fingerprint)" != "$fp" ] || [ -n "$(drift)" ]; then
  echo "L'index ou la copie de travail a changé pendant les vérifications, rien d'enregistré : relancer."
  exit 1
fi
if [ "$step" = all ]; then
  : >"$checks/$fp.static"
  : >"$checks/$fp.tests"
else
  : >"$checks/$fp.$step"
fi
# Deux appels séparés (static, tests) peuvent finir ensemble : chacun écrit son
# marqueur avant de chercher celui de l'autre, le dernier voit donc les deux.
if [ -f "$checks/$fp.static" ] && [ -f "$checks/$fp.tests" ]; then
  : >"$checks/$fp.verifier"
  echo "Index ${fp:0:7} vérifié : verdict enregistré pour le commit."
else
  echo "Étape $step : OK sur l'index ${fp:0:7} ; reste l'autre étape."
fi
exit 0
