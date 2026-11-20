/// Hachage FNV-1a de [text] (sur ses unités UTF-16), identique d'un lancement à l'autre
/// (contrairement à `String.hashCode`, que Dart ne garantit pas) et bien
/// réparti même entre des ids proches.
int stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}
