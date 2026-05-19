import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _userEmailKey = 'saved_user_email';
  static const String _userPasswordKey = 'saved_user_password';
  static const String _authMethodKey = 'auth_method'; // 'email' or 'google'

  Future<bool> canAuthenticate() async {
    try {
      final bool isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      final bool canCheck = await _auth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics =
          await _auth.getAvailableBiometrics();

      // Sur les versions récentes d'Android, les types précis (fingerprint/face) 
      // sont souvent masqués derrière les catégories de sécurité 'strong' ou 'weak'.
      // L'empreinte digitale est quasiment toujours classée en 'strong'.
      return canCheck && (
          availableBiometrics.contains(BiometricType.fingerprint) ||
          availableBiometrics.contains(BiometricType.strong)
      );
    } on PlatformException {
      return false;
    }
  }

  Future<bool> authenticate(String localizedReason) async {
    try {
      final bool authenticated = await _auth.authenticate(
        localizedReason: localizedReason,
      );
      return authenticated;
    } on PlatformException {
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _biometricEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    final String? value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }

  Future<void> saveCredentials(String email, String password) async {
    await _storage.write(key: _userEmailKey, value: email);
    await _storage.write(key: _userPasswordKey, value: password);
    await _storage.write(key: _authMethodKey, value: 'email');
  }

  Future<void> saveGoogleAuthMarker() async {
    await _storage.write(key: _authMethodKey, value: 'google');
  }

  Future<String?> getAuthMethod() async {
    return await _storage.read(key: _authMethodKey);
  }

  Future<Map<String, String>?> getCredentials() async {
    final String? email = await _storage.read(key: _userEmailKey);
    final String? password = await _storage.read(key: _userPasswordKey);

    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _userEmailKey);
    await _storage.delete(key: _userPasswordKey);
    await _storage.delete(key: _authMethodKey);
    await _storage.delete(key: _biometricEnabledKey);
  }
}
