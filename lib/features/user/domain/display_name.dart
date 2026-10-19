/// Prénom et nom tirés du nom affiché d'un compte (« Camille Martin ») : le
/// premier mot, puis le reste. [fallback] tient lieu de prénom quand le nom
/// affiché est vide.
({String name, String surname}) namesFromDisplayName(
  String displayName, {
  String fallback = '',
}) {
  final words = displayName.trim().split(RegExp(r'\s+'));
  final name = words.first;
  return (
    name: name.isEmpty ? fallback : name,
    surname: words.skip(1).join(' '),
  );
}
