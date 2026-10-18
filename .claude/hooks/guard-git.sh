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
if has 'firebase[[:space:]]+deploy'; then
  deny "le mainteneur déploie Firebase lui-même : dire ce qu'il faut déployer."
fi

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
