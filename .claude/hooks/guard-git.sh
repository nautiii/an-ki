#!/usr/bin/env bash
# Hook PreToolUse (Bash|PowerShell) : garde-fou des commandes git et Firebase.
# Bloque (code 2, motif renvoyé à l'agent) ce que le skill git-workflow interdit ;
# demande confirmation au mainteneur pour ce qui publie, réécrit l'historique ou
# efface du travail non commité. Les messages entre guillemets et les heredocs
# sont ignorés : un message de commit qui cite « git push » ne déclenche rien.
#
# Limite : le garde-fou de commit protège contre l'oubli, pas contre un
# contournement délibéré (git revert, cherry-pick, commit-tree, `bash -c`, un
# autre outil que git en ligne de commande, un chemin cité vers anki-checks…).

input=$(cat)
cmd=$(printf '%s' "$input" |
  sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(\([^"\\]\|\\.\)*\)".*/\1/p' |
  head -n 1)
# Dossier du dépôt : le cwd de l'appel, à défaut le dossier du projet.
cwd=$(printf '%s' "$input" |
  sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
  head -n 1 | sed 's/\\\\/\\/g')
dir=${cwd:-${CLAUDE_PROJECT_DIR:-.}}

deny() {
  printf 'Bloqué par .claude/hooks/guard-git.sh : %s\n' "$1" >&2
  exit 2
}
ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# Texte JSON → commande : guillemets dé-échappés, heredoc retiré, chaînes
# remplacées par _ (un argument cité reste un mot : `git -C "x" merge`). Une
# chaîne qui cite anki-checks devient le mot anki-checks : un chemin cité vers
# les marqueurs reste visible.
cmd=${cmd//\\\"/\"}
cmd=${cmd%%<<*}
# Les here-strings PowerShell (@' … '@, @" … "@, sur plusieurs lignes échappées en
# \n) deviennent _ d'abord : une apostrophe dans le message ne casse pas la suite.
hs_single="s/@'([^']|'[^@])*'@/_/g"
hs_double='s/@"([^"]|"[^@])*"@/_/g'
cmd=$(printf '%s' "$cmd" | sed -E -e "$hs_single" -e "$hs_double")
cmd=$(printf '%s' "$cmd" | sed -E "s/'[^']*anki-checks[^']*'/anki-checks/g; s/\"[^\"]*anki-checks[^\"]*\"/anki-checks/g; s/'[^']*'/_/g; s/\"[^\"]*\"/_/g")

# Commandes simples, une par ligne (séparées par ; & | ( ) ` ou un retour à la
# ligne), débarrassées de ce qui précède le vrai premier mot : mots-clés,
# affectations, préfixes (npx et ses options, timeout, env…). Une règle ne vise
# que les commandes dont ce premier mot est git ou firebase : le mot en argument
# (dossier, fichier, texte cherché, echo) n'en est pas un.
simple_commands() {
  printf '%s' "$cmd" | sed 's/\\n/\n/g' | tr ';&|()`' '\n\n\n\n\n\n' |
    sed -E 's/^[[:space:]]+//' |
    sed -E 's/^(((do|then|else|!|npx|exec|command|nohup|env)|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*|-[^[:space:]]+|timeout[[:space:]]+[^[:space:]]+)[[:space:]]+)+//'
}

# Les verdicts des agents de contrôle ne s'écrivent que par record-check.sh :
# une commande simple qui écrit dans anki-checks (commande d'écriture ou
# redirection) est refusée ; les lectures (ls, cat, grep) passent.
if printf '%s' "$cmd" | grep -q 'anki-checks'; then
  writers='touch|cp|mv|mkdir|rm|tee|New-Item|Set-Content|Add-Content|Out-File|Copy-Item|Move-Item|Remove-Item'
  if simple_commands | grep -E 'anki-checks' |
    grep -Eiq "^([^[:space:]]*[/\\\\])?($writers)(\\.exe)?([[:space:]]|$)"; then
    deny "les marqueurs anki-checks ne s'écrivent que par record-check.sh : lancer le verifier et le reviewer."
  fi
  if printf '%s' "$cmd" | sed 's/\\n/\n/g' | grep -Eq '>>?[[:space:]]*[^[:space:]]*anki-checks'; then
    deny "les marqueurs anki-checks ne s'écrivent que par record-check.sh : lancer le verifier et le reviewer."
  fi
fi

case "$cmd" in
  *git*|*firebase*) ;;
  *) exit 0 ;;
esac

git_cmds=$(simple_commands | grep -E '^([^[:space:]]*[/\\])?git(\.exe)?([[:space:]]|$)')

# Vrai si un appel git correspond au motif (ancré au début de l'appel).
has() { printf '%s' "$git_cmds" | grep -Eq -- "$1"; }

# Options globales de git avant la sous-commande : -c x, -C x, --git-dir[= ]x,
# --work-tree[= ]x, --namespace[= ]x, et les options sans valeur (--no-pager, -p,
# --paginate, --bare, --no-replace-objects, --literal-pathspecs…).
gopt='(-[cC][[:space:]]+[^[:space:]]+|--(git-dir|work-tree|namespace|exec-path|super-prefix|config-env)(=[^[:space:]]*|[[:space:]]+[^[:space:]]+)|--[a-z][a-z-]*|-[pP])'
git="^([^[:space:]]*[/\\\\])?git(\\.exe)?([[:space:]]+${gopt})*[[:space:]]+"
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
if has '^[^[:space:]]*git.*(--no-verify|--no-gpg-sign|gpgsign=false)'; then
  deny "ne jamais contourner les hooks git ni la signature : corriger la cause."
fi
if has "${git}push[^;&|]*[[:space:]](-f|--force)${end}"; then
  deny "push forcé sans bail : --force-with-lease, et seulement après le oui du mainteneur."
fi
# Firebase : seules les commandes locales ou en lecture seule passent. Le reste
# (deploy, suppressions, imports, connexion…) écrit en production ou touche au
# compte du mainteneur, qui le lance lui-même (skill firebase).
# Un appel est une commande simple dont le premier mot est firebase.
firebase_calls() {
  simple_commands |
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
done < <(firebase_calls)

# Un commit exige le verdict positif du verifier sur exactement l'index actuel
# (empreinte) et/ou la revue du reviewer depuis le dernier commit (marqueur lié
# à HEAD : une seule revue par commit). Marqueurs écrits par record-check.sh.
if has "${git}commit\\b"; then
  msg_index="commiter l'index tel quel : indexer les chemins avec git add, sans chemins après git commit."
  # Pas de -C, --git-dir, --work-tree ni cd : le dépôt vérifié est celui du cwd.
  if simple_commands | grep -Eq '^(cd|chdir|pushd|Push-Location|Set-Location|sl)([[:space:]]|$)'; then
    deny "commiter depuis le dossier du dépôt, sans -C ni cd."
  fi
  # Vrai dès qu'un appel commit n'est pas une simple reformulation (--amend --only).
  needs_verdict=''
  while IFS= read -r call; do
    call="$call "
    before=${call%%[[:space:]]commit[[:space:]]*}
    if printf '%s' "$before" | grep -Eq '(^|[[:space:]])(-C|--git-dir|--work-tree)([[:space:]=]|$)'; then
      deny "commiter depuis le dossier du dépôt, sans -C ni cd."
    fi
    args=${call#"$before"}
    args=${args# commit }
    # Arguments du commit : options (et valeurs des options qui en prennent une)
    # sautées, tout mot restant est un chemin.
    skip='' positional='' include='' only='' amend=''
    set -f
    for word in $args; do
      if [ -n "$skip" ]; then skip=''; continue; fi
      case "$word" in
        --) include=1 ;;
        --amend) amend=1 ;;
        --only) only=1 ;;
        --include | --pathspec-from-file | --pathspec-from-file=*) include=1 ;;
        --message | --file | --reuse-message | --reedit-message | --template | \
          --author | --date | --cleanup | --fixup | --squash | --trailer) skip=1 ;;
        --*) ;;
        -?*)
          # Grappe d'options courtes : un m, F, C, c ou t prend le reste de la
          # grappe pour valeur, ou le mot suivant s'il n'y a pas de reste.
          rest=${word#-}
          while [ -n "$rest" ]; do
            ch=${rest:0:1}
            rest=${rest:1}
            case "$ch" in
              i) include=1 ;;
              o) only=1 ;;
              u) break ;; # -u<mode> : le reste de la grappe est le mode
              m | F | C | c | t)
                [ -z "$rest" ] && skip=1
                break
                ;;
            esac
          done
          ;;
        *) positional=1 ;;
      esac
    done
    set +f
    if [ -n "$positional" ] || [ -n "$include" ]; then deny "$msg_index"; fi
    if [ -n "$only" ]; then
      # Reformulation d'un commit (amend --only, sans chemin) : aucun verdict.
      [ -n "$amend" ] || deny "$msg_index"
    else
      needs_verdict=1
    fi
  done < <(printf '%s\n' "$git_cmds" | grep -E "${git}commit([[:space:]]|\$)")

  if [ -n "$needs_verdict" ]; then
    staged=$(git -C "$dir" -c core.quotepath=off diff --cached --name-only --no-renames 2>/dev/null)
    need=''
    if printf '%s\n' "$staged" | grep -Eq '^(lib/|test/|android/|ios/|pubspec\.(yaml|lock)$|analysis_options\.yaml$|l10n\.yaml$|firestore\.rules$|firestore\.indexes\.json$|firebase\.json$)|\.dart$|\.arb$'; then
      need='verifier reviewer'
    elif printf '%s\n' "$staged" | grep -Eqv '(\.md$|^$)'; then
      need='reviewer'
    fi
    if [ -n "$need" ]; then
      gitdir=$(git -C "$dir" rev-parse --absolute-git-dir 2>/dev/null) ||
        deny "dépôt introuvable depuis le cwd du hook : commiter depuis le dossier du dépôt."
      # Empreinte de l'index (mode, blob et chemin de chaque entrée), sans verrou.
      tree=$(set -o pipefail; git -C "$dir" ls-files -s -z 2>/dev/null | git hash-object --stdin 2>/dev/null)
      head=$(git -C "$dir" rev-parse HEAD 2>/dev/null) || head=unborn
      [ -n "$head" ] || head=unborn
      missing=''
      for agent in $need; do
        if [ "$agent" = reviewer ]; then
          [ -f "$gitdir/anki-checks/head-$head.reviewer" ] ||
            missing="${missing:+$missing et }la revue du reviewer depuis le dernier commit (une seule revue par commit : appliquer ses remarques puis commiter)"
        else
          [ -n "$tree" ] && [ -f "$gitdir/anki-checks/$tree.$agent" ] ||
            missing="${missing:+$missing et }le verdict du verifier pour l'index actuel (empreinte ${tree:0:7})"
        fi
      done
      if [ -n "$missing" ]; then
        deny "commit refusé : il manque $missing. Le verifier doit repasser sur l'index exact après les corrections ; le reviewer ne repasse pas."
      fi
    fi
  fi
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
  git -C "$dir" merge-base --is-ancestor HEAD '@{u}' 2>/dev/null; then
  ask "réécrit des commits déjà poussés."
fi
exit 0
