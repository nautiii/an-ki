import 'package:an_ki/core/services/device_settings.dart';
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

  test('an unexpected stored value reads as not dismissed', () async {
    channels.storage['reminders_off_dismissed'] = 'yes';

    expect(await const DeviceSettings().remindersOffDismissed(), isFalse);
  });
}
