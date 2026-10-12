import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:flutter/foundation.dart';

/// Saisie d'un anniversaire avant enregistrement (formulaire ou import de
/// contacts → contrôleur → dépôt).
class const BirthdayDraft({
  required final String name,
  required final String surname,
  required final BirthDate date,
  final List<String> categories = const [],

  /// Nouvelle photo (octets compressés) ; null : pas de photo à la création,
  /// photo inchangée à la modification.
  final Uint8List? picture,
}) {
  /// Règle de saisie d'un prénom ou d'un nom : du texte, pas seulement des
  /// espaces. Le formulaire s'en sert pour valider ses champs.
  static bool isValidName(String value) => value.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is BirthdayDraft &&
      other.name == name &&
      other.surname == surname &&
      other.date == date &&
      listEquals(other.categories, categories) &&
      listEquals(other.picture, picture);

  @override
  int get hashCode => Object.hash(
    name,
    surname,
    date,
    Object.hashAll(categories),
    picture?.length,
  );
}
