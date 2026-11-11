import 'package:an_ki/features/books/domain/isbn.dart';
import 'package:an_ki/features/books/widgets/isbn_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/test_harness.dart';

void main() {
  /// L'ISBN renvoyé par la feuille, une fois fermée.
  String? returned;
  var closed = false;

  Future<void> openSheet(WidgetTester tester) async {
    returned = null;
    closed = false;
    await tester.pumpHarness(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            returned = await IsbnEntrySheet.show(context);
            closed = true;
          },
          child: const Text('Ouvrir'),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  }

  Finder field() => find.byType(TextField);

  Finder error() => find.text("Cet ISBN n'existe pas : vérifiez les chiffres");

  FilledButton addButton(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Ajouter'));

  testWidgets('"Ajouter" is disabled while the field is empty', (tester) async {
    await openSheet(tester);
    expect(find.text('Saisir un ISBN'), findsOneWidget);
    expect(addButton(tester).onPressed, isNull);

    await tester.enterText(field(), '9782');
    await tester.pump();
    expect(addButton(tester).onPressed, isNotNull);

    await tester.enterText(field(), '');
    await tester.pump();
    expect(addButton(tester).onPressed, isNull);
  });

  testWidgets('a wrong check digit shows an error and the sheet stays', (
    tester,
  ) async {
    await openSheet(tester);
    expect(error(), findsNothing);

    await tester.enterText(field(), '9782344059563');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(error(), findsOneWidget);
    expect(find.byType(IsbnEntrySheet), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('a valid ISBN-13 with hyphens returns it normalized', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.enterText(field(), '978-2-344-05956-2');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(returned, '9782344059562');
    expect(find.byType(IsbnEntrySheet), findsNothing);
  });

  testWidgets('an ISBN-10 returns its ISBN-13', (tester) async {
    await openSheet(tester);
    final expected = normalizeIsbn('2723488527');
    expect(expected, hasLength(13));

    await tester.enterText(field(), '2723488527');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(returned, expected);
  });

  testWidgets('submitting from the keyboard works too', (tester) async {
    await openSheet(tester);

    await tester.enterText(field(), '9782344059562');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(returned, '9782344059562');
    expect(closed, isTrue);
  });

  testWidgets('the error follows the typing once shown', (tester) async {
    await openSheet(tester);

    await tester.enterText(field(), '9782344059563');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(error(), findsOneWidget);

    await tester.enterText(field(), '9782344059562');
    await tester.pump();

    expect(error(), findsNothing);
  });

  testWidgets('an ISBN-10 ending with X can be typed', (tester) async {
    await openSheet(tester);
    final expected = normalizeIsbn('080442957X');
    expect(expected, hasLength(13));

    final input = tester.widget<TextField>(field());
    expect(input.keyboardType, TextInputType.text);
    await tester.enterText(field(), '0-8044-2957-x');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Ajouter'));
    await tester.pumpAndSettle();

    expect(returned, expected);
  });
}
