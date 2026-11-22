import 'package:an_ki/core/services/device_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/platform_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeBiometricChannels channels;

  setUp(() {
    // Le même stockage que l'empreinte, simulé en mémoire.
    channels = FakeBiometricChannels()..install();
  });

  tearDown(() => channels.uninstall());

  test('the reminders-off card is shown until dismissed', () async {
    // Les réglages tels que l'app les lit.
    final settings = ProviderContainer.test().read(deviceSettingsProvider);

    expect(await settings.remindersOffDismissed(), isFalse);

    await settings.dismissRemindersOff();

    expect(await settings.remindersOffDismissed(), isTrue);
    expect(channels.storage, containsPair('reminders_off_dismissed', 'true'));
  });

  test('remembers the last theme mode', () async {
    const settings = DeviceSettings();

    expect(await settings.lastThemeMode(), isNull);

    await settings.keepThemeMode(ThemeMode.dark);

    expect(await settings.lastThemeMode(), ThemeMode.dark);
    expect(channels.storage, containsPair('theme_mode', 'dark'));
  });

  test('an unknown stored theme reads as none', () async {
    channels.storage['theme_mode'] = 'sepia';

    expect(await const DeviceSettings().lastThemeMode(), isNull);
  });

  test('an unreadable storage reads as no theme', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => throw PlatformException(code: 'keystore'),
        );

    expect(await const DeviceSettings().lastThemeMode(), isNull);
  });

  test('an unexpected stored value reads as not dismissed', () async {
    channels.storage['reminders_off_dismissed'] = 'yes';

    expect(await const DeviceSettings().remindersOffDismissed(), isFalse);
  });
}
