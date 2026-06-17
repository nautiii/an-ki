import 'package:an_ki/core/services/biometric_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/platform_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeBiometricChannels channels;
  final service = BiometricService.instance;

  setUp(() {
    channels = FakeBiometricChannels();
    channels.install();
  });

  tearDown(() => channels.uninstall());

  group('canUseFingerprint', () {
    test('is true when the device supports a fingerprint sensor', () async {
      channels
        ..deviceSupported = true
        ..availableBiometrics = const ['fingerprint'];

      expect(await service.canUseFingerprint(), isTrue);
    });

    test('is false when the device is not supported', () async {
      channels.deviceSupported = false;

      expect(await service.canUseFingerprint(), isFalse);
    });

    test('is false when no biometrics are enrolled', () async {
      channels.availableBiometrics = const [];

      expect(await service.canUseFingerprint(), isFalse);
    });

    test('is false when only a non-matching biometric is available', () async {
      channels.availableBiometrics = const ['face'];

      expect(await service.canUseFingerprint(), isFalse);
    });

    test('is false when the platform throws', () async {
      channels.throwPlatformException = true;

      expect(await service.canUseFingerprint(), isFalse);
    });
  });

  group('authenticate', () {
    test('returns the platform result', () async {
      channels.authenticateResult = true;
      expect(await service.authenticate(), isTrue);

      channels.authenticateResult = false;
      expect(await service.authenticate(), isFalse);
    });

    test('returns false when the platform throws', () async {
      channels.throwPlatformException = true;

      expect(await service.authenticate(), isFalse);
    });
  });

  test('generateToken produces distinct non-empty tokens', () {
    final a = service.generateToken();
    final b = service.generateToken();

    expect(a, isNotEmpty);
    expect(a, isNot(b));
  });

  test('biometric data can be saved, read and cleared', () async {
    await service.saveBiometricData('user-1', 'token-123');

    expect(await service.getStoredToken(), 'token-123');
    expect(await service.getStoredUserId(), 'user-1');

    await service.clearBiometricData();

    expect(await service.getStoredToken(), isNull);
    expect(await service.getStoredUserId(), isNull);
  });
}
