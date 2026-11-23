import 'dart:async';

import 'package:an_ki/core/services/phone_contact_service.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/share_service.dart';
import 'package:an_ki/features/birthday/domain/wish_failure.dart';
import 'package:an_ki/features/birthday/providers/birthday_wisher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  late RecordingBirthdayRepository repository;
  late FakeShareService share;
  late FakePhoneContactService phone;

  setUp(() {
    repository = RecordingBirthdayRepository();
    share = FakeShareService();
    phone = FakePhoneContactService();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(share),
        phoneContactServiceProvider.overrideWithValue(phone),
      ],
    );
    // Provider autoDispose : un listener le garde en vie pendant le test.
    container.listen(birthdayWisherProvider, (_, _) {});
    return container;
  }

  Future<bool> wish(ProviderContainer container) => container
      .read(birthdayWisherProvider.notifier)
      .wish(birthdayId: 'lea', year: 2026, message: 'Joyeux anniversaire');

  test('marks the birthday wished once an app is chosen', () async {
    final container = makeContainer();

    expect(await wish(container), isTrue);
    expect(share.shared, ['Joyeux anniversaire']);
    expect(repository.wished, [('lea', 2026)]);
    expect(container.read(birthdayWisherProvider), isA<AsyncData<void>>());
  });

  test('changes nothing when the sheet is closed', () async {
    share.outcome = ShareOutcome.dismissed;
    final container = makeContainer();

    expect(await wish(container), isFalse);
    expect(repository.wished, isEmpty);
    expect(container.read(birthdayWisherProvider), isA<AsyncData<void>>());
  });

  test('fails when the sheet cannot open', () async {
    share.outcome = ShareOutcome.unavailable;
    final container = makeContainer();

    await expectLater(wish(container), throwsA(WishFailure.shareUnavailable));
    expect(repository.wished, isEmpty);
    expect(
      container.read(birthdayWisherProvider).error,
      WishFailure.shareUnavailable,
    );
  });

  test('fails when the platform throws', () async {
    share = FakeShareService(error: PlatformException(code: 'no-activity'));
    final container = makeContainer();

    await expectLater(wish(container), throwsA(WishFailure.shareUnavailable));
  });

  test('opens a single sheet at a time', () async {
    share.pending = Completer();
    final container = makeContainer();

    final first = wish(container);
    expect(container.read(birthdayWisherProvider).isLoading, isTrue);
    expect(await wish(container), isFalse);

    share.pending!.complete(ShareOutcome.shared);
    expect(await first, isTrue);
    expect(share.shared, hasLength(1));
  });

  group('a person linked to a contact', () {
    test('gets the wish by SMS, marked wished as the app opens', () async {
      final container = makeContainer();

      final wished = await container
          .read(birthdayWisherProvider.notifier)
          .wish(
            birthdayId: 'lea',
            year: 2026,
            message: 'Joyeux anniversaire',
            smsTo: '0611111111',
          );

      expect(wished, isTrue);
      expect(phone.texts, [('0611111111', 'Joyeux anniversaire')]);
      expect(share.shared, isEmpty);
      expect(repository.wished, [('lea', 2026)]);
    });

    test('without an SMS app, falls back to the share sheet', () async {
      phone.opens = false;
      final container = makeContainer();

      final wished = await container
          .read(birthdayWisherProvider.notifier)
          .wish(
            birthdayId: 'lea',
            year: 2026,
            message: 'Joyeux anniversaire',
            smsTo: '0611111111',
          );

      expect(wished, isTrue);
      expect(share.shared, ['Joyeux anniversaire']);
      expect(repository.wished, [('lea', 2026)]);
    });

    test('a call opens the dialer and counts as a wish', () async {
      final container = makeContainer();

      final called = await container
          .read(birthdayWisherProvider.notifier)
          .dial(birthdayId: 'lea', year: 2026, number: '0611111111');

      expect(called, isTrue);
      expect(phone.dialed, ['0611111111']);
      expect(repository.wished, [('lea', 2026)]);
    });

    test('without a phone app, a call fails and marks nothing', () async {
      phone.opens = false;
      final container = makeContainer();

      await expectLater(
        container
            .read(birthdayWisherProvider.notifier)
            .dial(birthdayId: 'lea', year: 2026, number: '0611111111'),
        throwsA(WishFailure.dialUnavailable),
      );
      expect(repository.wished, isEmpty);
      expect(
        container.read(birthdayWisherProvider).error,
        WishFailure.dialUnavailable,
      );
    });
  });
}
