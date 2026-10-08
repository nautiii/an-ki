#!/usr/bin/env bash
# Hook PostToolUse (Edit|Write) : formate le fichier Dart que l'agent vient d'écrire.
# Lit le JSON du hook sur stdin, sans dépendre de jq. N'échoue jamais : un fichier
# qui ne compile pas encore reste tel quel, l'analyse le signalera.

input=$(cat)
file=$(printf '%s' "$input" |
  sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
  head -n 1)
file=${file//\\\\/\\} # chemins Windows : « \\ » échappé en JSON → « \ »

case "$file" in
  *.dart) ;;
  *) exit 0 ;;
esac
if command -v cygpath >/dev/null 2>&1; then
  file=$(cygpath -u "$file")
fi
[ -f "$file" ] || exit 0

# Binaire Dart du SDK (~0,5 s) plutôt que le wrapper `flutter/bin/dart` (~2 s).
dart_bin=dart
if flutter_bin=$(command -v flutter 2>/dev/null); then
  sdk_dart="$(dirname "$flutter_bin")/cache/dart-sdk/bin/dart"
  if [ -x "$sdk_dart" ] || [ -x "$sdk_dart.exe" ]; then
    dart_bin=$sdk_dart
  fi
fi

"$dart_bin" format "$file" >/dev/null 2>&1
exit 0
