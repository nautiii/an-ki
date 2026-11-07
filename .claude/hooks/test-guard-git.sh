#!/usr/bin/env bash
# Auto-test de guard-git.sh : charges factices sur stdin, rien n'est exécuté.
# Usage : bash .claude/hooks/test-guard-git.sh (code 1 si un cas échoue ; node
# encode les charges ; plus de 2 min sous Windows : le lancer en arrière-plan).
# Le cwd des charges est un dossier hors dépôt : la garde de
# commit n'y lit aucun index, seules les règles de commande jouent.
cd "$(dirname "$0")/../.." || exit 1
w=$(mktemp -d)
trap 'rm -rf "$w"' EXIT
fails=0
# t <code attendu> <commande> [motif attendu dans le refus]
t() {
  local exp=$1 c=$2 want=${3:-} j rc err r=ok
  j=$(C="$c" W="$w" node -e 'process.stdout.write(JSON.stringify({tool_name:"Bash",tool_input:{command:process.env.C},cwd:process.env.W}))')
  err=$(printf '%s' "$j" | bash .claude/hooks/guard-git.sh 2>&1 >/dev/null)
  rc=$?
  [ "$rc" = "$exp" ] || r=FAIL
  if [ -n "$want" ] && ! printf '%s' "$err" | grep -q -- "$want"; then r=FAIL; fi
  [ "$r" = ok ] || fails=$((fails + 1))
  echo "$r rc=$rc (attendu $exp) :: $(printf '%s' "$c" | tr '\n' '|' | cut -c1-80)"
}
q="'"
nl=$'\n'
# Heredoc : le corps est ignoré, ce qui suit est examiné.
t 2 "git commit -F - <<${q}EOF${q}${nl}fix: x${nl}${nl}body${nl}EOF${nl}git merge feat/x" fusion
t 0 "git commit -F - <<${q}EOF${q}${nl}cite git merge feat/x et git push -f${nl}EOF"
t 2 "cat <<EOF | git commit -F -${nl}msg${nl}EOF${nl}git push --force" forcé
t 0 "cat <<-EOF${nl}	git merge x${nl}	EOF${nl}echo done"
t 2 "cat <<-EOF${nl}	body${nl}	EOF${nl}git merge x" fusion
t 0 "git commit -F - <<\"EOF\"${nl}l'apostrophe d'un message${nl}EOF"
t 0 "cat <<\\EOF${nl}git merge x${nl}EOF"
# Un << qui n'ouvre rien ne masque pas la suite.
t 2 "git commit -m \"fix <<EOF parsing\"${nl}git merge feat/x" fusion
t 2 "echo \$((1 << 2))${nl}git merge feat/x" fusion
t 0 'echo $((1 << 2))'
t 0 'printf "a\nb" | grep -c "<<EOF git merge x"'
# Here-string : son mot part avec l'opérateur.
t 0 'grep -c x <<< "git merge y"'
t 0 'git commit -F - <<< "fix: x"'
t 2 'git commit -F - <<< "fix: x"; git merge feat/x' fusion
t 0 'grep -c x <<< word && echo ok'
t 2 "grep -c x <<< word${nl}git merge feat/x" fusion
# Push forcé, forme courte de --no-verify.
t 2 'git push origin +main' forcé
t 2 'git push origin +HEAD:main' forcé
t 2 'git push --force origin main' forcé
t 0 'git push --force-with-lease origin feat/x'
t 2 'git commit -n -m x' contourner
t 2 'git commit -nm x' contourner
t 0 'git commit -uno -m x'
t 0 'git commit --amend --only --no-edit'
# Inchangé.
t 2 'git merge feat/x' fusion
t 0 'git merge --ff-only feat/x'
t 2 'git add -A' aveugle
t 2 'git add lib/main.dart && git commit -m x' 'deux appels'
t 0 'git status --short'
t 0 'echo hello'
echo "échecs : $fails"
[ "$fails" -eq 0 ]
