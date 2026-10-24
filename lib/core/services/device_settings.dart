import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Réglages propres à ce téléphone, hors du compte : ce que l'utilisateur y a
/// masqué. Porte mince sur le stockage de l'appareil, celui de l'empreinte :
/// pas de paquet de plus pour quelques booléens.
class DeviceSettings {
  const DeviceSettings({this._storage = const FlutterSecureStorage()});

  final FlutterSecureStorage _storage;

  static const _remindersOffDismissedKey = 'reminders_off_dismissed';

  /// Vrai si la carte « Rappels désactivés » a été masquée sur ce téléphone.
  Future<bool> remindersOffDismissed() async =>
      await _storage.read(key: _remindersOffDismissedKey) == 'true';

  /// Retient que la carte « Rappels désactivés » est masquée.
  Future<void> dismissRemindersOff() =>
      _storage.write(key: _remindersOffDismissedKey, value: 'true');
}

/// Réglages de ce téléphone, lus par les features à travers ce provider.
final deviceSettingsProvider = Provider<DeviceSettings>(
  (ref) => const DeviceSettings(),
);
