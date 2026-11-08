/// Date de sortie d'un tome, au jour ou au mois près.
///
/// Un type à part plutôt qu'un `DateTime` : une source sait souvent « décembre
/// 2026 » sans connaître le jour, et inventer un jour serait mentir. Stockée
/// en chaîne ISO (`2026-12-03`, `2026-12`), sans fuseau ni heure.
class const ReleaseDate({
  required final int year,
  required final int month,

  /// Jour du mois ; null quand seul le mois est connu.
  final int? day,
}) {
  /// Lit `2026-12-03` ou `2026-12` ; null pour toute autre forme ou une date
  /// qui n'existe pas (`2026-02-30`, `2026-13`).
  static ReleaseDate? tryParse(String text) {
    final match = _iso.firstMatch(text.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = match.group(3) == null ? null : int.parse(match.group(3)!);
    if (month < 1 || month > 12) return null;
    if (day != null) {
      // Un jour inexistant déborde sur le mois suivant : on le détecte ainsi.
      final real = DateTime.utc(year, month, day);
      if (real.month != month || day < 1) return null;
    }
    return ReleaseDate(year: year, month: month, day: day);
  }

  /// Vrai quand seul le mois est connu.
  bool get isMonthOnly => day == null;

  /// Forme stockée : `2026-12-03` ou `2026-12`.
  String get iso {
    final base = '${year.toString().padLeft(4, '0')}-${_two(month)}';
    final day = this.day;
    return day == null ? base : '$base-${_two(day)}';
  }

  /// Vrai si cette date n'est pas passée à [today] : le jour même compte, et un
  /// mois connu seul compte jusqu'à sa fin (son jour est inconnu, il peut être
  /// le dernier). Seuls l'année, le mois et le jour de [today] comptent.
  bool isOnOrAfter(DateTime today) {
    if (year != today.year) return year > today.year;
    if (month != today.month) return month > today.month;
    final day = this.day;
    return day == null || day >= today.day;
  }

  @override
  bool operator ==(Object other) =>
      other is ReleaseDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}

final _iso = RegExp(r'^(\d{4})-(\d{2})(?:-(\d{2}))?$');

String _two(int value) => value.toString().padLeft(2, '0');
