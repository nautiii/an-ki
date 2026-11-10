import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/books/data/bookshelf_repository.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/volume.dart';
import 'package:an_ki/features/books/providers/shelf_view.dart';
import 'package:an_ki/features/books/widgets/series_actions.dart';
import 'package:an_ki/features/books/widgets/shelf_undo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

Series _series(String id, String name) =>
    Series(id: id, name: name, keys: [name.toLowerCase()], complete: false);

Volume _volume(String id, String seriesId, int number) => Volume(
  id: id,
  seriesId: seriesId,
  number: number,
  title: 'T$number',
  authors: const [],
  lookup: LookupState.found,
  addedAt: DateTime(2026),
);

/// Montre les séries de l'étagère et le menu de la série « s1 ».
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = [
      for (final e
          in ref.watch(shelfSeriesListProvider).value ?? <ShelfEntry>[])
        e.series.name,
    ];
    final entry = ref.watch(seriesEntryProvider('s1')).value;
    return Column(
      children: [
        Text('Séries : ${names.join('|')}'),
        if (entry != null) SeriesMenu(entry: entry),
      ],
    );
  }
}

/// Compte que le test change en cours de route.
class _Uid extends Notifier<String?> {
  @override
  String? build() => 'fake-uid';

  void change(String? uid) => state = uid;
}

final _uidProvider = NotifierProvider<_Uid, String?>(_Uid.new);

void main() {
  late RecordingBookshelfRepository repository;

  Future<void> pumpHost(WidgetTester tester, {List<Series>? series}) async {
    repository = RecordingBookshelfRepository(
      series:
          series ??
          [
            _series('s1', 'One Piece'),
            _series('s2', 'Naruto'),
            _series('s3', 'Astérix'),
          ],
      volumes: [_volume('a', 's1', 1), _volume('b', 's1', 2)],
    );
    await tester.pumpHarness(
      const _Host(),
      overrides: [
        bookshelfRepositoryProvider.overrideWithValue(repository),
        currentUidProvider.overrideWithValue('fake-uid'),
      ],
    );
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Options de la série'));
    await tester.pumpAndSettle();
  }

  Future<void> letUndoExpire(WidgetTester tester) async {
    await tester.pump(shelfUndoDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  group('rename', () {
    testWidgets('asks with the current name and renames', (tester) async {
      await pumpHost(tester);
      await openMenu(tester);

      await tester.tap(find.text('Renommer'));
      await tester.pumpAndSettle();
      expect(find.text('Renommer la série'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'One Piece',
      );

      await tester.enterText(find.byType(TextField), 'One Piece (FR)');
      await tester.tap(find.widgetWithText(FilledButton, 'Renommer'));
      await tester.pumpAndSettle();

      expect(
        repository.series.firstWhere((s) => s.id == 's1').name,
        'One Piece (FR)',
      );
    });

    testWidgets('refuses an empty name', (tester) async {
      await pumpHost(tester);
      await openMenu(tester);
      await tester.tap(find.text('Renommer'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      // Le bouton reste désactivé, l'erreur s'affiche sous le champ.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Renommer'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Donnez un nom à la série'), findsOneWidget);
      expect(find.text('Renommer la série'), findsOneWidget);
      expect(
        repository.series.firstWhere((s) => s.id == 's1').name,
        'One Piece',
      );
    });

    testWidgets('cancelling or keeping the name writes nothing', (
      tester,
    ) async {
      await pumpHost(tester);
      await openMenu(tester);
      await tester.tap(find.text('Renommer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Renommer'));
      await tester.pumpAndSettle();

      expect(repository.series.firstWhere((s) => s.id == 's1').keys, [
        'one piece',
      ]);
      expect(find.text('Renommer la série'), findsNothing);
    });
  });

  group('merge', () {
    testWidgets('lists the other series A to Z', (tester) async {
      await pumpHost(tester);
      await openMenu(tester);
      await tester.tap(find.text('Fusionner avec une autre série'));
      await tester.pumpAndSettle();

      expect(find.text('Fusionner One Piece avec…'), findsOneWidget);
      final a = tester.getTopLeft(find.text('Astérix')).dy;
      final n = tester.getTopLeft(find.text('Naruto')).dy;
      expect(a, lessThan(n));
      // La source n'est pas proposée : un seul « One Piece », le titre.
      expect(find.text('One Piece'), findsNothing);
    });

    testWidgets('hides the source at once and merges after the snackbar', (
      tester,
    ) async {
      await pumpHost(tester);
      await openMenu(tester);
      await tester.tap(find.text('Fusionner avec une autre série'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Naruto'));
      await tester.pumpAndSettle();

      expect(find.text('Séries : Astérix|Naruto'), findsOneWidget);
      expect(find.text('One Piece fusionnée dans Naruto'), findsOneWidget);
      expect(repository.series.map((s) => s.id), contains('s1'));

      await letUndoExpire(tester);

      expect(repository.series.map((s) => s.id), isNot(contains('s1')));
      expect(repository.volumes.map((v) => v.seriesId).toSet(), {'s2'});
    });

    testWidgets('"Annuler" cancels the merge', (tester) async {
      await pumpHost(tester);
      await openMenu(tester);
      await tester.tap(find.text('Fusionner avec une autre série'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Naruto'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await letUndoExpire(tester);

      expect(repository.series.map((s) => s.id), contains('s1'));
      expect(find.text('Séries : Astérix|Naruto|One Piece'), findsOneWidget);
    });

    testWidgets('is disabled with a single series', (tester) async {
      await pumpHost(tester, series: [_series('s1', 'One Piece')]);
      await openMenu(tester);

      expect(
        find.ancestor(
          of: find.text('Fusionner avec une autre série'),
          matching: find.byWidgetPredicate(
            (w) => w is PopupMenuItem && !w.enabled,
          ),
        ),
        findsOneWidget,
      );
    });
  });

  group('complete', () {
    testWidgets('marks complete, and "Annuler" restores', (tester) async {
      await pumpHost(tester);
      await openMenu(tester);

      await tester.tap(find.text('Marquer comme terminée'));
      await tester.pumpAndSettle();

      expect(
        repository.series.firstWhere((s) => s.id == 's1').complete,
        isTrue,
      );
      expect(find.text('One Piece marquée terminée'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(
        repository.series.firstWhere((s) => s.id == 's1').complete,
        isFalse,
      );
    });

    testWidgets('a complete series offers to go back to ongoing', (
      tester,
    ) async {
      await pumpHost(
        tester,
        series: [
          const Series(id: 's1', name: 'One Piece', keys: [], complete: true),
        ],
      );
      await openMenu(tester);

      await tester.tap(find.text('Marquer comme en cours'));
      await tester.pumpAndSettle();

      expect(
        repository.series.firstWhere((s) => s.id == 's1').complete,
        isFalse,
      );
      expect(find.text('One Piece de nouveau en cours'), findsOneWidget);
      await letUndoExpire(tester);
    });
  });

  group('account changes before the snackbar closes', () {
    Future<void> pumpChangeable(WidgetTester tester) async {
      repository = RecordingBookshelfRepository(
        series: [_series('s1', 'One Piece'), _series('s2', 'Naruto')],
        volumes: [_volume('a', 's1', 1), _volume('b', 's1', 2)],
      );
      await tester.pumpHarness(
        const _Host(),
        overrides: [
          bookshelfRepositoryProvider.overrideWithValue(repository),
          currentUidProvider.overrideWith((ref) => ref.watch(_uidProvider)),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a deletion is not written for the new account', (
      tester,
    ) async {
      await pumpChangeable(tester);
      await openMenu(tester);
      await tester.tap(find.text('Supprimer la série'));
      await tester.pumpAndSettle();

      ProviderScope.containerOf(tester.element(find.byType(_Host)))
          .read(_uidProvider.notifier)
          .change('other-user');
      await tester.pump();
      await letUndoExpire(tester);

      expect(repository.series.map((s) => s.id), contains('s1'));
      expect(repository.volumes, hasLength(2));
    });

    testWidgets('the undo of "terminée" is not written for the new account', (
      tester,
    ) async {
      await pumpChangeable(tester);
      await openMenu(tester);
      await tester.tap(find.text('Marquer comme terminée'));
      await tester.pumpAndSettle();
      expect(repository.series.first.complete, isTrue);

      ProviderScope.containerOf(tester.element(find.byType(_Host)))
          .read(_uidProvider.notifier)
          .change('other-user');
      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      // L'annulation vise le compte d'origine : rien n'est réécrit.
      expect(repository.series.first.complete, isTrue);
    });
  });

  group('delete', () {
    testWidgets('hides the series, deletes it after the snackbar', (
      tester,
    ) async {
      await pumpHost(tester);
      await openMenu(tester);

      await tester.tap(find.text('Supprimer la série'));
      await tester.pumpAndSettle();

      expect(find.text('Séries : Astérix|Naruto'), findsOneWidget);
      expect(
        find.text('One Piece supprimée, avec ses 2 tomes'),
        findsOneWidget,
      );
      expect(repository.series.map((s) => s.id), contains('s1'));

      await letUndoExpire(tester);

      expect(repository.series.map((s) => s.id), isNot(contains('s1')));
      expect(repository.volumes, isEmpty);
    });

    testWidgets('"Annuler" brings the series back', (tester) async {
      await pumpHost(tester);
      await openMenu(tester);
      await tester.tap(find.text('Supprimer la série'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Annuler'));
      await letUndoExpire(tester);

      expect(repository.series.map((s) => s.id), contains('s1'));
      expect(repository.volumes, hasLength(2));
      expect(find.text('Séries : Astérix|Naruto|One Piece'), findsOneWidget);
    });
  });
}
