/// Plus grand numéro de tome accepté. Au-delà, c'est une année (« 2024 »), un
/// code ou une faute de frappe, et une étagère aurait des milliers de trous.
const maxVolumeNumber = 1000;

/// Numéro de tome d'un texte court (`15`, `T. 15`, `Tome 03`, `IV`, `[15]`) ;
/// null quand ce n'est pas un seul entier entre 1 et [maxVolumeNumber] :
/// décimal (`10.5`), intervalle (`3-4`), hors-série, texte.
int? parseVolumeNumber(String raw) {
  final text = raw.trim().replaceAll(RegExp(r'^[\[(]|[\])]$'), '').trim();
  final match = _numberText.firstMatch(text);
  if (match == null) return null;
  final digits = match.group(1);
  final value = digits != null
      ? int.parse(digits)
      : parseRoman(match.group(2)!);
  if (value == null || value < 1 || value > maxVolumeNumber) return null;
  return value;
}

/// Valeur d'un chiffre romain correct de I à CCCXCIX (`iv`, `XII`) ; null sinon.
int? parseRoman(String text) {
  final upper = text.toUpperCase();
  if (!_roman.hasMatch(upper)) return null;
  var total = 0;
  for (var i = 0; i < upper.length; i++) {
    final value = _romanValues[upper[i]]!;
    final next = i + 1 < upper.length ? _romanValues[upper[i + 1]]! : 0;
    total += value < next ? -value : value;
  }
  return total;
}

/// Un préfixe facultatif (`T`, `Tome`, `Vol.`, `n°`, `#`), puis un entier ou un
/// chiffre romain, et rien d'autre.
final _numberText = RegExp(
  r'^(?:(?:tome|vol(?:ume)?|t|n[°º]|no)\.?\s*|#\s*)?(?:(\d{1,4})|([ivxlc]+))$',
  caseSensitive: false,
);

final _roman = RegExp(
  r'^(?=[IVXLC])C{0,3}(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})$',
);

const _romanValues = {'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100};
