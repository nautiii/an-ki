#!/usr/bin/env bash
# Modèle du reviewer pour le diff indexé, lancé par la session principale juste
# avant la revue : Opus en effort high (le défaut de l'agent) au-delà de 50
# lignes ou dès qu'une zone sensible est touchée, Sonnet en effort medium
# sinon. Un changement structurant ou système (AGENTS.md, « Size the change »)
# prend Opus quoi que dise ce script.

root=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "pas de dépôt git ici : lancer depuis le dossier du dépôt" >&2
  exit 2
}
cd "$root" || exit 2

# Lignes ajoutées et retirées, hors markdown (jamais revu), fichiers générés et
# pubspec.lock.
lines=$(git diff --cached --numstat --no-renames -- . ':(exclude)*.md' \
  ':(exclude)lib/l10n/app_localizations*.dart' ':(exclude)pubspec.lock' |
  awk '$1 != "-" { n += $1 + $2 } END { print n + 0 }')
# Zones sensibles : état et données (providers, data, domain), rappels et
# services, composition et navigation, Firebase, dépendances, plateformes,
# garde-fous des commits, test d'architecture.
zones='^lib/features/[^/]+/(providers|data|domain)/|^lib/features/reminders/|^lib/core/(providers|services)/|^lib/app/|^lib/main\.dart$|^firestore\.(rules|indexes\.json)$|^firebase\.json$|^pubspec\.yaml$|^(android|ios)/|^\.claude/(hooks/|settings\.json$)|^test/architecture/'
sensitive=$(git -c core.quotepath=off diff --cached --name-only --no-renames |
  grep -E "$zones" | sed -E 's#/[^/]+$#/#' | sort -u | head -n 4 | paste -sd ' ')

if ! git diff --cached --name-only | grep -Evq '(\.md$|^$)'; then
  echo "Rien à revoir : l'index ne contient que du markdown."
  exit 0
fi
if [ "$lines" -gt 50 ] || [ -n "$sensitive" ]; then
  echo "Revue : $lines lignes${sensitive:+, zones sensibles : $sensitive} → opus, effort high (défaut de l'agent : ne passer ni model ni effort)."
else
  echo "Revue : $lines lignes, aucune zone sensible → model: sonnet, effort: medium (sauf changement structurant : opus)."
fi
