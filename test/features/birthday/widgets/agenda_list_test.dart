import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:an_ki/features/birthday/domain/agenda.dart';
import 'package:an_ki/features/birthday/domain/birth_date.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/birthday/widgets/agenda_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';
import '../../../support/test_harness.dart';

void main() {
  final today = DateTime(2026, 10, 12);

  testWidgets('names each period in French, the year only when it changes', (
    tester,
  ) async {
    final context = await tester.pumpLocalizedContext();

    expect(
      agendaPeriodLabel(context, const AgendaSoon(), today),
      'Dans les 7 jours',
    );
    expect(
      agendaPeriodLabel(context, const AgendaMonth(2026, 11), today),
      'Novembre',
    );
    expect(
      agendaPeriodLabel(context, const AgendaMonth(2027, 1), today),
      'Janvier 2027',
    );
  });

  testWidgets('keeps each header as tall as its text when the size changes', (
    tester,
  ) async {
    const lea = Birthday(
      id: 'lea',
      name: 'Léa',
      surname: 'Martin',
      date: BirthDate(month: 10, day: 15),
    );
    await tester.pumpHarness(
      const CustomScrollView(slivers: [AgendaSliver()]),
      overrides: [
        ...defaultTestOverrides,
        todayProvider.overrideWithValue(today),
        agendaProvider.overrideWithValue(const [
          AgendaSection(period: AgendaSoon(), birthdays: [lea]),
        ]),
      ],
    );
    double header() => tester.getSize(find.byType(AgendaSectionHeader)).height;
    final normal = header();

    // Le texte grossit pendant que l'accueil est ouvert.
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();

    expect(header(), greaterThan(normal));
  });
}
