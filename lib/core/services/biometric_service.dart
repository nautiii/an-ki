import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';

class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _biometricTokenKey = 'biometric_auth_token';
  static const String _userIdKey = 'biometric_user_id';

  /// Vérifie si l'authentification par empreinte digitale est disponible.
  Future<bool> canUseFingerprint() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      final bool canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();

      // On cible uniquement les empreintes (souvent classées en 'strong' sur Android 12+)
      return availableBiometrics.contains(BiometricType.fingerprint) ||
          availableBiometrics.contains(BiometricType.strong);
    } on PlatformException {
      return false;
    }
  }

  /// Lance l'authentification biométrique (Empreinte uniquement, pas de PIN).
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Veuillez scanner votre empreinte pour vous connecter',
        biometricOnly: true,
      );
    } on PlatformException {
      return false;
    }
  }

  /// Génère un nouveau token unique.
  String generateToken() {
    return const Uuid().v4();
  }

  /// Enregistre le token et l'ID utilisateur dans le stockage sécurisé.
  Future<void> saveBiometricData(String userId, String token) async {
    await _storage.write(key: _biometricTokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
  }

  /// Récupère le token stocké localement.
  Future<String?> getStoredToken() async {
    return await _storage.read(key: _biometricTokenKey);
  }

  /// Récupère l'ID utilisateur associé au token.
  Future<String?> getStoredUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  /// Supprime les données biométriques locales.
  Future<void> clearBiometricData() async {
    await _storage.delete(key: _biometricTokenKey);
    await _storage.delete(key: _userIdKey);
  }
}
