import 'package:flutter/foundation.dart';

/// Profil de l'utilisateur : identité, catégories suivies et préférences
/// d'affichage.
///
/// Modèle de domaine : Dart pur, immuable, sans Firebase ni Flutter UI. La
/// conversion Firestore vit dans `data/user_repository.dart`.
class const UserModel({
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

  /// Copie modifiée. Un argument null signifie « inchangé » ; `clearX` vide
  /// un champ optionnel.
  UserModel copyWith({
    String? name,
    String? surname,
    String? pseudo,
    bool clearPseudo = false,
    List<String>? categories,
    bool? isDark,
    String? locale,
    String? biometricToken,
    bool clearBiometricToken = false,
  }) => UserModel(
    id: id,
    name: name ?? this.name,
    surname: surname ?? this.surname,
    pseudo: clearPseudo ? null : pseudo ?? this.pseudo,
    categories: categories ?? this.categories,
    isDark: isDark ?? this.isDark,
    locale: locale ?? this.locale,
    biometricToken: clearBiometricToken
        ? null
        : biometricToken ?? this.biometricToken,
  );

  @override
  bool operator ==(Object other) =>
      other is UserModel &&
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
