#!/usr/bin/env bash
# Hook PreToolUse (Bash|PowerShell) : garde-fou des commandes git et Firebase.
# Bloque (code 2, motif renvoyé à l'agent) ce que le skill git-workflow interdit ;
# demande confirmation au mainteneur pour ce qui publie, réécrit l'historique ou
# efface du travail non commité. Les messages entre guillemets et les heredocs
# sont ignorés : un message de commit qui cite « git push » ne déclenche rien.

input=$(cat)
cmd=$(printf '%s' "$input" |
  sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p' |
  head -n 1)
case "$cmd" in
  *git*|*firebase*) ;;
  *) exit 0 ;;
esac

# Texte JSON → commande : guillemets dé-échappés, heredoc et chaînes retirés.
cmd=${cmd//\\\"/\"}
cmd=${cmd%%<<*}
cmd=$(printf '%s' "$cmd" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

has() { printf '%s' "$cmd" | grep -Eq -- "$1"; }
deny() {
  printf 'Bloqué par .claude/hooks/guard-git.sh : %s\n' "$1" >&2
  exit 2
}
ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

git='git([[:space:]]+-[cC][[:space:]]+[^[:space:]]+)*[[:space:]]+'
end='([[:space:]]|[;&|)]|$)'

# Interdit (skill git-workflow).
if has "${git}merge\\b" && ! has "${git}merge[^;&|]*--(ff-only|abort)"; then
  deny "pas de commit de fusion : rebaser la branche puis git merge --ff-only."
fi
if has "${git}pull\\b" && ! has "${git}pull[^;&|]*--(rebase|ff-only)"; then
  deny "git pull sans --rebase ni --ff-only crée un commit de fusion."
fi
if has "${git}add[^;&|]*[[:space:]](-A|--all|\\.|:/)${end}" ||
  has "${git}add[^;&|]*[[:space:]](-u|--update)[[:space:]]*($|[;&|])"; then
  deny "git add en aveugle : indexer des chemins explicites (le mainteneur travaille en parallèle)."
fi
if has "${git}commit[^;&|]*[[:space:]](-[b-zA-Z]*a[a-zA-Z]*|--all)${end}"; then
  deny "git commit -a embarque tout le travail en cours : indexer des chemins explicites."
fi
if has '--no-verify|--no-gpg-sign|gpgsign=false'; then
  deny "ne jamais contourner les hooks git ni la signature : corriger la cause."
fi
if has "${git}push[^;&|]*[[:space:]](-f|--force)${end}"; then
  deny "push forcé sans bail : --force-with-lease, et seulement après le oui du mainteneur."
fi
# Firebase : seules les commandes locales ou en lecture seule passent. Le reste
# (deploy, suppressions, imports, connexion…) écrit en production ou touche au
# compte du mainteneur, qui le lance lui-même (skill firebase).
# Un appel est une commande simple (séparée par ; & | ( ) ` ou un retour à la
# ligne) dont le premier mot, une fois retirés mots-clés, affectations et
# préfixes (npx et ses options, timeout, env…), est firebase : le mot en argument
# (dossier, fichier, texte cherché) n'en est pas un.
firebase_calls() {
  printf '%s' "$1" | sed 's/\\n/\n/g' | tr ';&|()`' '\n\n\n\n\n\n' |
    sed -E 's/^[[:space:]]+//' |
    sed -E 's/^(((do|then|else|!|npx|exec|command|nohup|env)|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|-[^[:space:]]+|timeout[[:space:]]+[^[:space:]]+)[[:space:]]+)+//' |
    grep -E '^([^[:space:]]*[/\\])?firebase(-tools)?(@[^[:space:]]*)?(\.cmd|\.exe)?([[:space:]]|$)'
}
# Sous-commande d'un appel (les mots après la commande), options globales et
# leurs valeurs sautées.
firebase_subcommand() {
  local - rest='' skip='' word
  set -f
  case "$1" in *[[:space:]]*) rest=${1#*[[:space:]]} ;; esac
  for word in $rest; do
    if [ -n "$skip" ]; then skip=''; continue; fi
    case "$word" in
      --project | -P | --config | -c | --token | --account) skip=1 ;;
      --version | -V | --help | -h) printf '%s' "$word"; return ;;
      -*) ;;
      *) printf '%s' "$word"; return ;;
    esac
  done
}
# `deploy --dry-run` limité à Firestore ne fait que compiler les règles et lire
# l'état du projet (testRuleset) : rien n'est créé ni publié.
firestore_dry_run() {
  printf '%s' "$1" | grep -Eq -- '--dry-run([[:space:]]|$)' &&
    printf '%s' "$1" | grep -Eq -- '--only[[:space:]=]+firestore(:(rules|indexes))?(,firestore(:(rules|indexes))?)*([[:space:]]|$)'
}
while IFS= read -r call; do
  # Une aide n'agit jamais.
  if printf '%s' "$call" | grep -Eq -- '[[:space:]](--help|-h)([[:space:]]|$)'; then continue; fi
  case "$(firebase_subcommand "$call")" in
    '' | emulators:start | emulators:exec | emulators:export | firestore:indexes | \
      login:list | projects:list | apps:list | apps:sdkconfig | use | help | \
      --version | -V) ;;
    deploy)
      firestore_dry_run "$call" ||
        deny "le mainteneur déploie Firebase lui-même : dire ce qu'il faut déployer (--dry-run --only firestore:rules reste permis pour compiler)."
      ;;
    *) deny "commande Firebase réservée au mainteneur (production ou compte) : dire ce qu'il faut lancer." ;;
  esac
done < <(firebase_calls "$cmd")

# À confirmer par le mainteneur.
if has "${git}push\\b"; then
  ask "git push publie l'historique sur le dépôt distant."
fi
if has "${git}reset[^;&|]*--hard"; then
  ask "git reset --hard efface le travail non commité."
fi
if has "${git}clean[^;&|]*[[:space:]]-[a-zA-Z]*f"; then
  ask "git clean -f supprime des fichiers non suivis."
fi
if has "${git}(checkout|restore)[^;&|]*[[:space:]]\\.${end}"; then
  ask "efface toutes les modifications non commitées."
fi
if has "${git}branch[^;&|]*[[:space:]]-D${end}"; then
  ask "supprime une branche, même non intégrée."
fi
if has "${git}stash[[:space:]]+(drop|clear)"; then
  ask "supprime du travail mis de côté."
fi
if has "${git}(commit[^;&|]*--amend|rebase)\\b" &&
  git -C "${CLAUDE_PROJECT_DIR:-.}" merge-base --is-ancestor HEAD '@{u}' 2>/dev/null; then
  ask "réécrit des commits déjà poussés."
fi
exit 0
