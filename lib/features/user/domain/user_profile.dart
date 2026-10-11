import 'package:flutter/foundation.dart';

/// Profil de l'utilisateur : identité, catégories suivies et préférences
/// d'affichage.
///
/// Modèle de domaine : Dart pur, immuable, sans Firebase ni Flutter UI. La
/// conversion Firestore vit dans `data/user_repository.dart`.
class const UserProfile({
  required final String id,
  required final String name,
  required final String surname,
  final String? pseudo,
  final List<String> categories = const [],
  required final bool isDark,
  required final String locale,
  final String? biometricToken,
}) {
  /// Nom affiché dans l'UI : le pseudo s'il est défini, sinon « nom prénom ».
  String get displayName {
    final pseudo = this.pseudo;
    if (pseudo != null && pseudo.isNotEmpty) return pseudo;
    return '$surname $name';
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.name == name &&
      other.surname == surname &&
      other.pseudo == pseudo &&
      listEquals(other.categories, categories) &&
      other.isDark == isDark &&
      other.locale == locale &&
      other.biometricToken == biometricToken;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    surname,
    pseudo,
    Object.hashAll(categories),
    isDark,
    locale,
    biometricToken,
  );
}
