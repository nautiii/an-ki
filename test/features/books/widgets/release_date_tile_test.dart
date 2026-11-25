import 'package:an_ki/features/books/domain/release_date.dart';
import 'package:an_ki/features/books/widgets/release_date_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  testWidgets('a day shows its number and weekday', (tester) async {
    await tester.pumpHarness(
      const ReleaseDateTile(date: ReleaseDate(year: 2026, month: 12, day: 3)),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.text('jeu.'), findsOneWidget);
  });

  testWidgets('a month alone shows the month', (tester) async {
    await tester.pumpHarness(
      const ReleaseDateTile(date: ReleaseDate(year: 2027, month: 1)),
    );

    expect(find.text('janv.'), findsOneWidget);
  });

  testWidgets('is mute: the row around it says the date', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpHarness(
      const ReleaseDateTile(date: ReleaseDate(year: 2026, month: 12, day: 3)),
    );

    expect(find.bySemanticsLabel(RegExp('3|jeu')), findsNothing);
    semantics.dispose();
  });
}
