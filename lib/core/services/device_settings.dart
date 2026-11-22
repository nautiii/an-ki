import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Réglages propres à ce téléphone, hors du compte : ce que l'utilisateur y a
/// masqué, le thème du dernier profil chargé. Porte mince sur le stockage de
/// l'appareil, celui de l'empreinte : pas de paquet de plus pour quelques
/// valeurs.
class DeviceSettings {
  const DeviceSettings();

  static const _storage = FlutterSecureStorage();

  static const _remindersOffDismissedKey = 'reminders_off_dismissed';
  static const _themeModeKey = 'theme_mode';

  /// Vrai si la carte « Rappels désactivés » a été masquée sur ce téléphone.
  Future<bool> remindersOffDismissed() async =>
      await _storage.read(key: _remindersOffDismissedKey) == 'true';

  /// Retient que la carte « Rappels désactivés » est masquée.
  Future<void> dismissRemindersOff() =>
      _storage.write(key: _remindersOffDismissedKey, value: 'true');

  /// Thème du dernier profil chargé sur ce téléphone ; null s'il n'y en a
  /// pas encore, si la valeur est inconnue ou si le stockage ne répond pas
  /// (lu au démarrage : quelle que soit l'erreur, il ne doit jamais
  /// l'empêcher).
  Future<ThemeMode?> lastThemeMode() async {
    try {
      final stored = await _storage.read(key: _themeModeKey);
      return ThemeMode.values.asNameMap()[stored];
    } catch (_) {
      return null;
    }
  }

  /// Retient [mode] pour le prochain démarrage.
  Future<void> keepThemeMode(ThemeMode mode) =>
      _storage.write(key: _themeModeKey, value: mode.name);
}

/// Réglages de ce téléphone, lus par les features à travers ce provider.
final deviceSettingsProvider = Provider<DeviceSettings>(
  (ref) => const DeviceSettings(),
);
