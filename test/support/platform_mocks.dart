import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// In-memory mock of the `local_auth` and `flutter_secure_storage` platform
/// channels so [BiometricService] can run in unit tests.
class FakeBiometricChannels {
  final Map<String, String?> storage = {};
  bool deviceSupported = true;
  List<String> availableBiometrics = const ['fingerprint'];
  bool authenticateResult = true;
  bool throwPlatformException = false;

  static const _localAuth = MethodChannel('plugins.flutter.io/local_auth');
  static const _secureStorage = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void install() {
    _messenger.setMockMethodCallHandler(_localAuth, (call) async {
      if (throwPlatformException) {
        throw PlatformException(code: 'NotAvailable');
      }
      switch (call.method) {
        case 'isDeviceSupported':
          return deviceSupported;
        case 'getAvailableBiometrics':
          return availableBiometrics;
        case 'authenticate':
          return authenticateResult;
      }
      return null;
    });

    _messenger.setMockMethodCallHandler(_secureStorage, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return storage[key];
        case 'write':
          storage[key!] = args['value'] as String?;
          return null;
        case 'delete':
          storage.remove(key);
          return null;
        case 'containsKey':
          return storage.containsKey(key);
        case 'readAll':
          return storage;
        case 'deleteAll':
          storage.clear();
          return null;
      }
      return null;
    });
  }

  void uninstall() {
    _messenger.setMockMethodCallHandler(_localAuth, null);
    _messenger.setMockMethodCallHandler(_secureStorage, null);
  }
}

/// A no-op [GoogleSignInPlatform] so flows that call `signOut()`/`disconnect()`
/// do not hit real platform channels. Interactive sign-in is not supported.
class FakeGoogleSignInPlatform extends GoogleSignInPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) => Future<AuthenticationResults?>.value();

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(AuthenticateParameters params) {
    throw UnimplementedError('authenticate is not supported in tests');
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}
