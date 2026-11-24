import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/domain/series.dart';
import 'package:an_ki/features/books/domain/shelf.dart';
import 'package:an_ki/features/books/domain/shelf_agenda.dart';
import 'package:an_ki/features/books/widgets/upcoming_releases.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

final _today = DateTime(2026, 11, 24);

UpcomingRelease _release(String name, ReleaseDate date) {
  final series = Series(
    id: name,
    name: name,
    keys: [name.toLowerCase()],
    complete: false,
  );
  return UpcomingRelease(
    entry: shelfOf([series], const []).entries.single,
    number: 109,
    date: date,
  );
}

void main() {
  final onePiece = _release(
    'One Piece',
    const ReleaseDate(year: 2026, month: 12, day: 3),
  );
  final tomorrow = _release(
    'Naruto',
    const ReleaseDate(year: 2026, month: 11, day: 25),
  );
  final month = _release('Dune', const ReleaseDate(year: 2027, month: 1));

  Future<List<UpcomingRelease>> pumpReleases(WidgetTester tester) async {
    final opened = <UpcomingRelease>[];
    await tester.pumpHarness(
      SingleChildScrollView(
        child: UpcomingReleases(
          releases: [tomorrow, onePiece, month],
          today: _today,
          onOpen: opened.add,
        ),
      ),
    );
    return opened;
  }

  testWidgets('says when each volume comes out', (tester) async {
    await pumpReleases(tester);

    expect(find.text('Prochaines sorties'), findsOneWidget);
    expect(find.text('One Piece · tome 109'), findsOneWidget);
    expect(find.text('dans 9 jours'), findsOneWidget);
    expect(find.text('demain'), findsOneWidget);
    // Un mois seul : le mois, pas de jour inventé.
    expect(find.text('janvier 2027'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('holds at 200 % text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpReleases(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('One Piece · tome 109'), findsOneWidget);
  });

  testWidgets('a row opens its series', (tester) async {
    final opened = await pumpReleases(tester);

    await tester.tap(find.text('One Piece · tome 109'));

    expect(opened, [onePiece]);
  });

  testWidgets('reads each row as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpReleases(tester);

    expect(
      find.bySemanticsLabel(
        'One Piece, tome 109, sort le jeudi 3 décembre, dans 9 jours',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Dune, tome 109, sort en janvier 2027'),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
  });
}
