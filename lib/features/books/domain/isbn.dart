/// Vrai pour l'ISBN-13 d'un livre, tel que l'imprime son code-barres
/// EAN-13 : 13 chiffres commençant par 978 ou 979. Les autres codes (QR,
/// produits) ne vont pas jusqu'à Google Books.
bool isBookIsbn(String code) => _isbn13.hasMatch(code);

final _isbn13 = RegExp(r'^97[89]\d{10}$');
