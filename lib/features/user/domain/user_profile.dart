import 'package:flutter/foundation.dart';

/// Thème choisi : celui du téléphone (par défaut), toujours clair ou toujours
/// sombre. `themeProvider` le traduit en `ThemeMode` pour l'app.
enum ThemePreference { system, light, dark }

/// Profil de l'utilisateur : identité, préférences d'affichage et choix des
/// modules.
///
/// Modèle de domaine : Dart pur, immuable, sans Firebase ni Flutter UI. La
/// conversion Firestore vit dans `data/user_repository.dart`.
class const UserProfile({
  required final String id,
  required final String name,
  required final String surname,
  final String? pseudo,
  final ThemePreference theme = ThemePreference.system,

  /// Langue choisie (`fr`, `en`) ; null : celle du téléphone.
  final String? locale,
  final String? biometricToken,

  /// Choix explicites de l'utilisateur, par id de module (`books: true`) ;
  /// un module absent suit son réglage par défaut. La feature `user` stocke
  /// ces ids sans savoir ce qu'est un module (`app/modules/`).
  final Map<String, bool> moduleChoices = const {},
}) {
  /// Nom pour saluer : le pseudo s'il est défini, sinon le prénom ; null s'il
  /// n'y a ni l'un ni l'autre. Pour un invité ([guest]), le pseudo seul : son
  /// profil peut porter « Invité », qu'écrivaient les versions précédentes.
  String? greetingName({required bool guest}) {
    final pseudo = this.pseudo?.trim() ?? '';
    if (pseudo.isNotEmpty) return pseudo;
    final name = this.name.trim();
    return guest || name.isEmpty ? null : name;
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.name == name &&
      other.surname == surname &&
      other.pseudo == pseudo &&
      other.theme == theme &&
      other.locale == locale &&
      other.biometricToken == biometricToken &&
      mapEquals(other.moduleChoices, moduleChoices);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    surname,
    pseudo,
    theme,
    locale,
    biometricToken,
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in moduleChoices.entries)
        Object.hash(key, value),
    ]),
  );
}
