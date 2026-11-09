import 'dart:async';

import 'package:an_ki/app/modules/app_module.dart';
import 'package:an_ki/app/modules/module_data_eraser.dart';
import 'package:an_ki/app/modules/module_data_hooks.dart';
import 'package:an_ki/app/modules/module_registry.dart';
import 'package:an_ki/core/providers/user_data_hooks.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/probe_module.dart';

void main() {
  /// Le contrôleur, connecté comme [uid], avec les effaceurs [erasers].
  ProviderContainer makeContainer(
    Map<String, UserDataEraser> erasers, {
    String? uid = 'u1',
  }) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        moduleErasersProvider.overrideWithValue(erasers),
      ],
    );
    container.listen(moduleDataEraserProvider, (_, _) {});
    return container;
  }

  test('erases the data of that module for the signed-in account', () async {
    final erased = <String>[];
    final container = makeContainer({
      'books': (uid) async => erased.add('books:$uid'),
      'gifts': (uid) async => erased.add('gifts:$uid'),
    });

    final done = await container
        .read(moduleDataEraserProvider.notifier)
        .erase('books');

    expect(done, isTrue);
    expect(erased, ['books:u1']);
    expect(container.read(moduleDataEraserProvider), isA<AsyncData<void>>());
  });

  test('offline, refuses and says so', () async {
    final container = makeContainer({
      'books': (_) async => throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      ),
    });

    final done = await container
        .read(moduleDataEraserProvider.notifier)
        .erase('books');

    expect(done, isFalse);
    expect(
      container.read(moduleDataEraserProvider).error,
      isA<FirebaseException>(),
    );
  });

  test('is loading while it erases, and ignores a second tap', () async {
    final pending = Completer<void>();
    var calls = 0;
    final container = makeContainer({
      'books': (_) {
        calls++;
        return pending.future;
      },
    });
    final eraser = container.read(moduleDataEraserProvider.notifier);

    final first = eraser.erase('books');
    expect(container.read(moduleDataEraserProvider).isLoading, isTrue);
    expect(await eraser.erase('books'), isFalse);

    pending.complete();
    expect(await first, isTrue);
    expect(calls, 1);
  });

  test('does nothing without a session or for a module without data', () async {
    var calls = 0;
    Future<void> count(String _) async => calls++;

    expect(
      await makeContainer({
        'books': count,
      }, uid: null).read(moduleDataEraserProvider.notifier).erase('books'),
      isFalse,
    );
    expect(
      await makeContainer({'books': count})
          .read(moduleDataEraserProvider.notifier)
          .erase('birthdays'),
      isFalse,
    );
    expect(calls, 0);
  });

  test('the registry gives each module with data its eraser', () async {
    final erased = <String>[];
    final container = ProviderContainer.test(
      overrides: [
        appModulesProvider.overrideWithValue([
          probeModule(),
          probeModule(
            id: 'gifts',
            data: ModuleData(
              eraser: (_) =>
                  (uid) async => erased.add(uid),
            ),
          ),
        ]),
      ],
    );

    final erasers = container.read(moduleErasersProvider);
    expect(erasers.keys, ['gifts']);
    await erasers['gifts']!('u1');

    expect(erased, ['u1']);
  });
}
