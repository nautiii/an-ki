import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/data/birthday_repository.dart';
import 'package:an_ki/features/birthday/data/category_repository.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthday_category.dart';
import 'package:an_ki/features/birthday/widgets/add_birthday_sheet.dart';
import 'package:an_ki/features/birthday/widgets/add_mode_switch.dart';
import 'package:an_ki/features/birthday/widgets/birthday_form_sheet.dart';
import 'package:an_ki/features/birthday/widgets/quick_add_sheet.dart';
import 'package:an_ki/features/user/data/user_repository.dart';
import 'package:an_ki/features/user/domain/user_profile.dart';
import 'package:an_ki/features/user/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/network_image_mock.dart';
import '../../../support/test_harness.dart';

void main() {
  const friend = BirthdayCategory(id: 'fri', name: 'friend', icon: 0xe1bf);

  /// Le profil, dont le mode d'ajout retenu ([quickAdd]).
  RecordingUserRepository users({bool quickAdd = false}) =>
      RecordingUserRepository(
        stored: UserProfile(
          id: 'fake-uid',
          name: 'A',
          surname: 'B',
          locale: 'fr',
          quickAddPreferred: quickAdd,
        ),
      );

  /// Un bouton « Ouvrir » qui lance l'ajout comme l'accueil ; il est touché
  /// tout de suite.
  Future<void> openAdd(
    WidgetTester tester, {
    required RecordingUserRepository profiles,
    RecordingBirthdayRepository? birthdays,
    String? name,
  }) => mockNetworkImages(() async {
    await tester.pumpHarness(
      // Le profil est écouté, comme dans l'app : chargé avant l'ouverture.
      Consumer(
        builder: (context, ref, _) => Center(
          child: TextButton(
            key: ValueKey(ref.watch(userProfileProvider).value),
            onPressed: () => AddBirthdaySheet.show(context, name: name),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
      overrides: [
        clockProvider.overrideWithValue(() => DateTime(2026, 11, 15, 9)),
        currentUidProvider.overrideWithValue('fake-uid'),
        birthdayRepositoryProvider.overrideWithValue(
          birthdays ?? RecordingBirthdayRepository(),
        ),
        categoryRepositoryProvider.overrideWithValue(
          RecordingCategoryRepository([friend]),
        ),
        userRepositoryProvider.overrideWithValue(profiles),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
  });

  final nameField = find.widgetWithText(TextField, 'Prénom et nom');
  final dateField = find.widgetWithText(TextField, "Date d'anniversaire");
  final lineField = find.widgetWithText(TextField, 'Qui, et quand ?');

  String textOf(WidgetTester tester, Finder field) =>
      tester.widget<TextField>(field).controller!.text;

  Set<AddMode> selectedMode(WidgetTester tester) => tester
      .widget<SegmentedButton<AddMode>>(find.byType(SegmentedButton<AddMode>))
      .selected;

  testWidgets('opens on the form by default, the mode switch on top', (
    tester,
  ) async {
    await openAdd(tester, profiles: users());

    expect(find.byType(BirthdayFormSheet), findsOneWidget);
    expect(find.byType(QuickAddSheet), findsNothing);
    expect(selectedMode(tester), {AddMode.form});
    expect(find.text('Formulaire'), findsOneWidget);
    expect(find.text('En une ligne'), findsOneWidget);
  });

  testWidgets('opens on the one-line add when it was picked last', (
    tester,
  ) async {
    await openAdd(tester, profiles: users(quickAdd: true), name: 'Léa');

    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(selectedMode(tester), {AddMode.line});
    expect(textOf(tester, lineField), 'Léa ');
  });

  testWidgets('switches to one line in place, keeping what was typed, and '
      'remembers it', (tester) async {
    final profiles = users();
    await openAdd(tester, profiles: profiles);
    await tester.enterText(nameField, 'Léa Martin');
    await tester.enterText(dateField, '1203');
    await tester.tap(find.byType(FilterChip).first);
    await tester.pump();

    await tester.tap(find.text('En une ligne'));
    await tester.pumpAndSettle();

    // Même feuille, autre mode : la ligne reprend le nom et la date.
    expect(find.byType(AddBirthdaySheet), findsOneWidget);
    expect(find.byType(BirthdayFormSheet), findsNothing);
    expect(textOf(tester, lineField), 'Léa Martin 12/03 ');
    expect(find.text('Le 12 mars'), findsOneWidget);
    final chip = tester.widget<FilterChip>(find.byType(FilterChip).first);
    expect(chip.selected, isTrue);
    expect(profiles.updated.last.quickAddPreferred, isTrue);
  });

  testWidgets('switches back to the form with what the line understood', (
    tester,
  ) async {
    final profiles = users(quickAdd: true);
    await openAdd(tester, profiles: profiles);
    await tester.enterText(lineField, 'Hugo Bernard 17 novembre 1990');
    await tester.pump();

    await tester.tap(find.text('Formulaire'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsNothing);
    expect(textOf(tester, nameField), 'Hugo Bernard');
    expect(textOf(tester, dateField), '17/11/1990');
    expect(profiles.updated.last.quickAddPreferred, isFalse);
  });

  testWidgets('keeps an unfinished date across a round trip', (tester) async {
    await openAdd(tester, profiles: users());
    await tester.enterText(nameField, 'Zoé');
    await tester.enterText(dateField, '12');

    await tester.tap(find.text('En une ligne'));
    await tester.pumpAndSettle();
    expect(textOf(tester, lineField), 'Zoé 12 ');

    await tester.tap(find.text('Formulaire'));
    await tester.pumpAndSettle();
    expect(textOf(tester, nameField), 'Zoé');

    // Rien de touché dans le formulaire : la ligne revient intacte.
    await tester.tap(find.text('En une ligne'));
    await tester.pumpAndSettle();
    expect(textOf(tester, lineField), 'Zoé 12 ');
  });

  testWidgets('the new field takes the focus, keyboard open', (tester) async {
    await openAdd(tester, profiles: users());
    await tester.enterText(nameField, 'Zoé');

    await tester.tap(find.text('En une ligne'));
    await tester.pumpAndSettle();
    EditableText editable(Finder field) => tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable(lineField).focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Formulaire'));
    await tester.pumpAndSettle();
    // Le nom est là : la date attend.
    expect(editable(dateField).focusNode.hasFocus, isTrue);
  });

  testWidgets('a pasted list keeps the one-line mode', (tester) async {
    await openAdd(tester, profiles: users(quickAdd: true));
    await tester.enterText(lineField, 'Léa 12 mars\nZoé 1/1');
    await tester.pumpAndSettle();

    final form = tester.widget<SegmentedButton<AddMode>>(
      find.byType(SegmentedButton<AddMode>),
    );
    expect(form.segments.first.enabled, isFalse);
    await tester.tap(find.text('Formulaire'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(textOf(tester, lineField), 'Léa 12 mars\nZoé 1/1');

    // Une seule ligne : le formulaire redevient possible.
    await tester.enterText(lineField, 'Léa 12 mars');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<AddMode>>(
            find.byType(SegmentedButton<AddMode>),
          )
          .segments
          .first
          .enabled,
      isTrue,
    );
  });

  testWidgets('follows a profile arriving late, until the first keystroke', (
    tester,
  ) async {
    final profiles = users();
    await openAdd(tester, profiles: profiles);
    expect(find.byType(BirthdayFormSheet), findsOneWidget);

    // Un autre appareil choisit la ligne : rien n'est encore tapé.
    await profiles.setQuickAddPreferred('fake-uid', quickAdd: true);
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddSheet), findsOneWidget);

    await tester.enterText(lineField, 'Léa');
    await tester.pump();
    await profiles.setQuickAddPreferred('fake-uid', quickAdd: false);
    await tester.pumpAndSettle();
    // Saisie commencée : le mode ne change plus sous les doigts.
    expect(find.byType(QuickAddSheet), findsOneWidget);
    expect(textOf(tester, lineField), 'Léa');
  });

  testWidgets('adds from either mode', (tester) async {
    final birthdays = RecordingBirthdayRepository();
    await openAdd(tester, profiles: users(), birthdays: birthdays);
    await tester.tap(find.text('En une ligne'));
    await tester.pumpAndSettle();

    await tester.enterText(lineField, 'Léa 12 mars');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AddBirthdaySheet), findsNothing);
    expect(birthdays.created.single.date, const BirthDate(month: 3, day: 12));
  });

  testWidgets('editing has no mode switch', (tester) async {
    await mockNetworkImages(() async {
      await tester.pumpHarness(
        const BirthdayFormSheet(
          birthdayToEdit: Birthday(
            id: 'lea',
            name: 'Léa',
            surname: '',
            date: BirthDate(month: 3, day: 12),
          ),
        ),
        overrides: [
          currentUidProvider.overrideWithValue('fake-uid'),
          categoryRepositoryProvider.overrideWithValue(
            RecordingCategoryRepository([friend]),
          ),
          userRepositoryProvider.overrideWithValue(users()),
        ],
      );
      await tester.pumpAndSettle();
    });

    expect(find.byType(AddModeSwitch), findsNothing);
  });

  testWidgets('meets the tap target and label guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await openAdd(tester, profiles: users());

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
