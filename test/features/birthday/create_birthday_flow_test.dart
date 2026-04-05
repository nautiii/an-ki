import 'package:an_ki/data/models/birthday_model.dart';
import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/features/birthday/home_page.dart';
import 'package:an_ki/providers/birthday_provider.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../support/fake_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'HomePage opens the create birthday page from the floating button',
    (WidgetTester tester) async {
      final FakeBirthdayProvider birthdayProvider = FakeBirthdayProvider();

      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _TestApp(birthdayProvider: birthdayProvider),
      );
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('Nouvel anniversaire'), findsOneWidget);
    },
  );

  testWidgets('Create birthday flow submits a new birthday to the provider', (
    WidgetTester tester,
  ) async {
    final FakeBirthdayProvider birthdayProvider = FakeBirthdayProvider();

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_TestApp(birthdayProvider: birthdayProvider));
    await tester.pump();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Thomas');
    await tester.enterText(find.byType(TextFormField).last, 'Leroy');

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    expect(birthdayProvider.createdInputs, hasLength(1));
    expect(birthdayProvider.createdInputs.single.name, 'Thomas');
    expect(birthdayProvider.createdInputs.single.surname, 'Leroy');
    expect(
      birthdayProvider.createdInputs.single.category,
      BirthdayCategory.friend,
    );
    expect(find.text('Nouvel anniversaire'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.birthdayProvider});

  final FakeBirthdayProvider birthdayProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>.value(
          value: FakeUserProvider(
            initialUser: const UserModel(
              id: '1',
              name: 'Marie',
              surname: 'Martin',
            ),
          ),
        ),
        ChangeNotifierProvider<BirthdayProvider>.value(value: birthdayProvider),
      ],
      child: const MaterialApp(home: HomePage()),
    );
  }
}

