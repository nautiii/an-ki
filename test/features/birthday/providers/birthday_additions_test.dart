import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/birthday/providers/birthday_additions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Session que le test change à la main.
final _session = NotifierProvider<_Session, String?>(_Session.new);

class _Session extends Notifier<String?> {
  @override
  String? build() => 'u1';

  void signIn(String? uid) => state = uid;
}

void main() {
  const imported = BirthdaysAdded(count: 2, imported: true, first: false);

  ProviderContainer makeContainer() => ProviderContainer.test(
    retry: (_, _) => null,
    overrides: [currentUidProvider.overrideWith((ref) => ref.watch(_session))],
  );

  test('starts empty, then holds the last addition', () {
    final container = makeContainer();
    expect(container.read(birthdayAdditionsProvider), isNull);

    container.read(birthdayAdditionsProvider.notifier).record(imported);

    expect(container.read(birthdayAdditionsProvider), imported);
  });

  test('announces every addition, even one equal to the last', () {
    final container = makeContainer();
    final heard = <BirthdaysAdded?>[];
    container.listen(birthdayAdditionsProvider, (_, next) => heard.add(next));

    container.read(birthdayAdditionsProvider.notifier)
      ..record(imported)
      ..record(imported);

    expect(heard, [imported, imported]);
  });

  test('forgets the addition when the account changes', () {
    final container = makeContainer();
    container.listen(birthdayAdditionsProvider, (_, _) {});
    container.read(birthdayAdditionsProvider.notifier).record(imported);

    container.read(_session.notifier).signIn('u2');

    expect(container.read(birthdayAdditionsProvider), isNull);
  });
}
