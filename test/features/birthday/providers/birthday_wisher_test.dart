import 'dart:async';

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

  setUp(() {
    repository = RecordingBirthdayRepository();
    share = FakeShareService();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        birthdayRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('u1'),
        shareServiceProvider.overrideWithValue(share),
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
}
