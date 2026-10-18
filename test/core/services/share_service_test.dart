import 'package:an_ki/core/services/share_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Canal de share_plus : la réponse native dit ce que la personne a fait.
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  final calls = <MethodCall>[];

  /// La plateforme répond [reply] à chaque partage.
  void reply(String? reply) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return reply;
        });
  }

  setUp(calls.clear);
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('shares the text and reports the app chosen', () async {
    reply('com.whatsapp/com.whatsapp.ContactPicker');

    final outcome = await const ShareService().shareText('Joyeux anniversaire');

    expect(outcome, ShareOutcome.shared);
    expect(calls.single.method, 'share');
    expect(
      (calls.single.arguments as Map<Object?, Object?>)['text'],
      'Joyeux anniversaire',
    );
  });

  test('reports a sheet closed without choosing', () async {
    reply('');

    expect(
      await const ShareService().shareText('Joyeux anniversaire'),
      ShareOutcome.dismissed,
    );
  });

  test('reports a sheet that could not open', () async {
    reply(null);

    expect(
      await const ShareService().shareText('Joyeux anniversaire'),
      ShareOutcome.unavailable,
    );
  });
}
