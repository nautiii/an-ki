#!/usr/bin/env bash
# Lancé par le reviewer à la fin de sa revue du diff indexé, juste avant de rendre
# son rapport. Une revue couvre un changement logique, que la session commite
# ensuite en un ou plusieurs commits atomiques : le marqueur
# <gitdir>/anki-checks/<horodatage>-<pid>.review garde la base (HEAD au moment de
# la revue) puis les chemins indexés au moment où il tourne, hors markdown.
# guard-git.sh accepte pendant 48 h un commit dont chaque chemin a été revu et
# pas encore commité (ou est un nouveau fichier de test), tant que la base
# reste un ancêtre de HEAD (review_covers). guard-git.sh refuse cette commande
# hors du reviewer.

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "pas de dépôt git ici : lancer depuis le dossier du dépôt" >&2
  exit 2
}
base=$(git -C "$root" rev-parse --verify -q HEAD) || {
  echo "pas encore de commit : rien à quoi lier la revue" >&2
  exit 2
}
paths=$(git -C "$root" -c core.quotepath=off diff --cached --name-only --no-renames |
  grep -Ev '\.md$')
if [ -z "$paths" ]; then
  echo "rien d'indexé hors markdown : aucune revue à enregistrer" >&2
  exit 1
fi
checks="$(git -C "$root" rev-parse --absolute-git-dir)/anki-checks"
marker="$checks/$(date +%Y%m%d%H%M%S)-$$.review"
mkdir -p "$checks" &&
  printf '%s\n%s\n' "$base" "$paths" >"$marker.tmp" &&
  mv "$marker.tmp" "$marker" || exit 2
echo "Revue enregistrée : $(printf '%s\n' "$paths" | wc -l | tr -d ' ') chemins depuis ${base:0:7}, valable pour les commits de ce changement."
