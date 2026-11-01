#!/usr/bin/env bash
# Lancé par le reviewer à la fin de sa revue du diff indexé, juste avant de rendre
# son rapport : écrit <gitdir>/anki-checks/head-<HEAD>.reviewer, le marqueur que
# guard-git.sh exige avant un commit qui n'est pas que du markdown. Une revue par
# commit : le marqueur vaut jusqu'au commit suivant, remarques appliquées.
# guard-git.sh refuse cette commande hors du reviewer.

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "pas de dépôt git ici : lancer depuis le dossier du dépôt" >&2
  exit 2
}
if git -C "$root" diff --cached --quiet; then
  echo "rien d'indexé : aucune revue à enregistrer" >&2
  exit 1
fi
checks="$(git -C "$root" rev-parse --absolute-git-dir)/anki-checks"
head=$(git -C "$root" rev-parse HEAD 2>/dev/null) || head=unborn
mkdir -p "$checks" && : >"$checks/head-$head.reviewer" || exit 2
echo "Revue enregistrée pour le commit qui suivra ${head:0:7}."
