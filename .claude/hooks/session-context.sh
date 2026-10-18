#!/usr/bin/env bash
# Hook SessionStart : met l'état git sous les yeux de l'agent dès le départ. Le
# mainteneur commite et indexe en parallèle (Android Studio, autres sessions) :
# ce constat vieillit vite, il se re-vérifie avant d'écrire, supprimer ou commiter.

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

branch=$(git branch --show-current)
counts=$(git rev-list --left-right --count '@{u}...HEAD' 2>/dev/null)
echo "Git at session start — it changes under you: re-check before writing, deleting or committing."
if [ -n "$counts" ]; then
  echo "Branch ${branch:-(detached)}: ${counts%%[[:space:]]*} behind, ${counts##*[[:space:]]} ahead of upstream."
else
  echo "Branch ${branch:-(detached)}, no upstream."
fi
echo "Last commits:"
git log --oneline -3
changes=$(git status --short)
if [ -z "$changes" ]; then
  echo "Working tree clean."
else
  total=$(printf '%s\n' "$changes" | wc -l | tr -d ' ')
  echo "Uncommitted ($total; anything staged goes into the next commit):"
  printf '%s\n' "$changes" | head -n 20
  [ "$total" -gt 20 ] && echo "…"
fi
exit 0
