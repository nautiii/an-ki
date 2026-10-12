import 'package:an_ki/features/birthday/domain/agenda.dart';
import 'package:an_ki/features/birthday/widgets/agenda_list.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
