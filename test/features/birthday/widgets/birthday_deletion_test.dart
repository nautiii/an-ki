import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/birthday_deletion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

const _lea = Birthday(
  id: 'lea',
  name: 'Léa',
  surname: 'Martin',
  date: BirthDate(month: 3, day: 12),
);

/// Session que le test change à la main.
final _session = NotifierProvider<_Session, String?>(_Session.new);

class _Session extends Notifier<String?> {
  @override
  String? build() => 'fake-uid';

  void signIn(String? uid) => state = uid;
}

void main() {
  late RecordingBirthdayRepository birthdays;

  setUp(() => birthdays = RecordingBirthdayRepository(initial: const [_lea]));

  /// Un bouton qui supprime Léa avec « Annuler ».
  Future<void> pumpDeletion(WidgetTester tester) async {
    await tester.pumpHarness(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => deleteWithUndo(context, _lea),
          child: const Text('Supprimer Léa'),
        ),
      ),
      overrides: [
        currentUidProvider.overrideWith((ref) => ref.watch(_session)),
        birthdayRepositoryProvider.overrideWithValue(birthdays),
      ],
    );
    await tester.tap(find.text('Supprimer Léa'));
    await tester.pumpAndSettle();
  }

  testWidgets('deletes once « Annuler » is gone', (tester) async {
    await pumpDeletion(tester);
    expect(birthdays.deleted, isEmpty);

    await tester.pump(undoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(birthdays.deleted, ['lea']);
  });

  testWidgets('leaves twice as long to undo with TalkBack', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpDeletion(tester);

    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      undoDelay * 2,
    );
  });

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.text('Supprimer Léa')));

  testWidgets('« Annuler » keeps the birthday', (tester) async {
    await pumpDeletion(tester);
    // Masquée pendant le délai.
    expect(containerOf(tester).read(pendingDeletionsProvider), {'lea'});

    await tester.tap(find.text('Annuler'));
    await tester.pump(undoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(birthdays.deleted, isEmpty);
    expect(containerOf(tester).read(pendingDeletionsProvider), isEmpty);
  });

  testWidgets('a failed deletion brings the birthday back', (tester) async {
    birthdays = RecordingBirthdayRepository(
      initial: const [_lea],
      failure: Exception('unavailable'),
    );
    await pumpDeletion(tester);

    await tester.pump(undoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(birthdays.deleted, isEmpty);
    expect(containerOf(tester).read(pendingDeletionsProvider), isEmpty);
  });

  testWidgets('a switch of account during « Annuler » deletes nothing', (
    tester,
  ) async {
    await pumpDeletion(tester);
    ProviderScope.containerOf(tester.element(find.text('Supprimer Léa')))
        .read(_session.notifier)
        .signIn('other-uid');

    await tester.pump(undoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(birthdays.deleted, isEmpty);
  });
}
