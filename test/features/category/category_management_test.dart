import 'package:an_ki/features/birthday/widgets/category_form_sheet.dart';
import 'package:an_ki/features/birthday/providers/category_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_harness.dart';
import '../../support/fake_providers.dart';

void main() {
  testWidgets('CategoryFormSheet allows creating a custom category', (tester) async {
    final categoryNotifier = FakeCategoryNotifier();

    await tester.pumpHarness(
      const CategoryFormSheet(),
      overrides: [
        categoryNotifierProvider.overrideWith(() => categoryNotifier),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Nouvelle catégorie'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Work');
    await tester.tap(find.text('Ajouter').last);
    await tester.pumpAndSettle();

    expect(categoryNotifier.createdNames, contains('Work'));
  });
}
