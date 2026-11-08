/// Vrai pour l'ISBN-13 d'un livre, tel que l'imprime son code-barres
/// EAN-13 : 13 chiffres commençant par 978 ou 979. Les autres codes (QR,
/// produits) ne vont pas jusqu'à Google Books.
bool isBookIsbn(String code) => _isbn13.hasMatch(code);

final _isbn13 = RegExp(r'^97[89]\d{10}$');

/// ISBN-13 de [input] saisi à la main ou lu quelque part, ou null quand ce
/// n'est pas un ISBN valide.
///
/// Retire espaces, tirets (aussi typographiques) et un préfixe « ISBN » ;
/// convertit un ISBN-10 en ISBN-13 (préfixe 978) ; vérifie la clé de contrôle,
/// ce qu'[isBookIsbn] ne fait pas : une faute de frappe est rattrapée ici.
String? normalizeIsbn(String input) {
  final compact = input
      .replaceFirst(_isbnLabel, '')
      .replaceAll(RegExp(r'[\s\-‐‑–—−]'), '');
  if (compact.length == 13) {
    if (!isBookIsbn(compact)) return null;
    return _isbn13CheckDigit(compact.substring(0, 12)) == compact[12]
        ? compact
        : null;
  }
  if (compact.length == 10 && _isbn10.hasMatch(compact)) {
    if (!_isbn10IsValid(compact)) return null;
    final body = '978${compact.substring(0, 9)}';
    return '$body${_isbn13CheckDigit(body)}';
  }
  return null;
}

final _isbnLabel = RegExp(
  r'^\s*isbn(?:[-\s]?1[03])?\s*:?',
  caseSensitive: false,
);

/// Neuf chiffres puis un dernier chiffre ou X.
final _isbn10 = RegExp(r'^\d{9}[\dXx]$');

/// Clé de contrôle (modulo 10, poids 1 et 3) des 12 premiers chiffres.
String _isbn13CheckDigit(String twelve) {
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(twelve[i]) * (i.isEven ? 1 : 3);
  }
  return ((10 - sum % 10) % 10).toString();
}

/// Clé de contrôle d'un ISBN-10 (modulo 11, poids 10 à 1 ; X vaut 10).
bool _isbn10IsValid(String isbn) {
  var sum = 0;
  for (var i = 0; i < 10; i++) {
    final char = isbn[i];
    final value = char == 'X' || char == 'x' ? 10 : int.parse(char);
    // X n'est permis qu'en dernière position.
    if (value == 10 && i != 9) return false;
    sum += value * (10 - i);
  }
  return sum % 11 == 0;
}
