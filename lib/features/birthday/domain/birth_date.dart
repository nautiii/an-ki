/// Date de naissance d'une personne : jour, mois et, quand on la connaît,
/// année.
///
/// Un type à part plutôt qu'un `DateTime` : une date de naissance n'a ni
/// heure ni fuseau, son année peut manquer, et chaque règle dit
/// explicitement ce qu'elle en utilise.
class const BirthDate({
  required final int month,
  required final int day,

  /// Année de naissance ; null quand on l'ignore (« le 15 octobre », sans
  /// plus) : aucun âge n'est alors calculé ni affiché.
  final int? year,
}) {
  /// Depuis une date du calendrier : seuls l'année, le mois et le jour comptent.
  factory BirthDate.fromDate(DateTime date) =>
      BirthDate(year: date.year, month: date.month, day: date.day);

  @override
  bool operator ==(Object other) =>
      other is BirthDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}
