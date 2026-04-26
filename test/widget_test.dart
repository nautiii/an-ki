import 'package:an_ki/core/app_initializer.dart';
import 'package:an_ki/data/models/user_model.dart';
import 'package:an_ki/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_providers.dart';

void main() {
  testWidgets('AppInitializer loads the user after the first frame', (
    WidgetTester tester,
  ) async {
    final FakeUserProvider userProvider = FakeUserProvider();
    userProvider.preparePendingLoad();

    await tester.pumpWidget(
      ChangeNotifierProvider<UserProvider>.value(
        value: userProvider,
        child: const MaterialApp(home: AppInitializer(child: TestChild())),
      ),
    );

    expect(find.text('Child ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pump();

    expect(userProvider.receivedName, 'Maillard');
    expect(userProvider.receivedSurname, 'Quentin');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Child ready'), findsNothing);
    expect(tester.takeException(), isNull);

    userProvider.completePendingLoad(
      const UserModel(id: '1', name: 'Quentin', surname: 'Maillard'),
    );
    await tester.pump();

    expect(find.text('Child ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class TestChild extends StatefulWidget {
  const TestChild({super.key});

  @override
  State<TestChild> createState() => _TestChildState();
}

class _TestChildState extends State<TestChild> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Child ready')));
  }
}
