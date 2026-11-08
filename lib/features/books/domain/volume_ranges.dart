import 'package:an_ki/features/books/domain/volume_number.dart';

/// Résultat de la lecture d'une saisie comme `1-12, 15` : les numéros, ou ce
/// qui ne va pas. Aucun texte d'UI : l'écran choisit le message.
sealed class VolumeRanges {
  const VolumeRanges();
}

/// Les numéros saisis, triés, sans doublon.
class const ParsedVolumeRanges({required final List<int> numbers})
    extends VolumeRanges {
  @override
  bool operator ==(Object other) =>
      other is ParsedVolumeRanges && _sameNumbers(other.numbers, numbers);

  @override
  int get hashCode => Object.hashAll(numbers);
}

/// La saisie est refusée pour [problem].
class const RejectedVolumeRanges({required final VolumeRangesProblem problem})
    extends VolumeRanges {
  @override
  bool operator ==(Object other) =>
      other is RejectedVolumeRanges && other.problem == problem;

  @override
  int get hashCode => problem.hashCode;
}

enum VolumeRangesProblem {
  /// Rien de saisi.
  empty,

  /// Un morceau n'est pas un numéro ni un intervalle (`abc`, `1-`, `0`).
  malformed,

  /// Un intervalle à l'envers (`12-1`).
  inverted,

  /// Un numéro ou un intervalle dépasse [maxVolumeNumber].
  tooLarge,
}

/// Lit une saisie de numéros de tomes comme `1-12, 15`.
///
/// Tolère espaces, virgule, point-virgule, `et`, `&`, et pour un intervalle le
/// tiret (aussi typographique : `‐`, `–`, `—`, `−`), `à` ou `a` sans accent
/// (clavier de téléphone) et `..` (`1 à 12`, `1 a 12`, `1 – 12`). Les numéros
/// sortent triés et sans doublon.
VolumeRanges parseVolumeRanges(String input) {
  final text = input
      .toLowerCase()
      .replaceAll(
        RegExp(
          r'\s*(?:[-‐‑–—−]+|\.\.|(?<![\p{L}])[àa](?![\p{L}]))\s*',
          unicode: true,
        ),
        '-',
      )
      .trim();
  if (text.isEmpty) {
    return const RejectedVolumeRanges(problem: VolumeRangesProblem.empty);
  }

  final numbers = <int>{};
  for (final part in text.split(RegExp(r'[\s,;&]+|\bet\b'))) {
    if (part.isEmpty) continue;
    final match = _part.firstMatch(part);
    if (match == null) {
      return const RejectedVolumeRanges(problem: VolumeRangesProblem.malformed);
    }
    final from = int.parse(match.group(1)!);
    final to = match.group(2) == null ? from : int.parse(match.group(2)!);
    if (from < 1 || to < 1) {
      return const RejectedVolumeRanges(problem: VolumeRangesProblem.malformed);
    }
    if (to < from) {
      return const RejectedVolumeRanges(problem: VolumeRangesProblem.inverted);
    }
    if (to > maxVolumeNumber) {
      return const RejectedVolumeRanges(problem: VolumeRangesProblem.tooLarge);
    }
    for (var n = from; n <= to; n++) {
      numbers.add(n);
    }
  }
  if (numbers.isEmpty) {
    return const RejectedVolumeRanges(problem: VolumeRangesProblem.empty);
  }
  return ParsedVolumeRanges(numbers: numbers.toList()..sort());
}

/// Un numéro ou un intervalle `a-b`.
final _part = RegExp(r'^(\d{1,9})(?:-(\d{1,9}))?$');

bool _sameNumbers(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
