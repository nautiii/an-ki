import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:flutter/widgets.dart';

/// Libellé d'un moment de rappel, dans la langue de l'app ; partagé par la
/// fiche d'un anniversaire et les réglages des rappels.
extension ReminderLeadDisplay on BuildContext {
  /// « 30 jours avant », « 7 jours avant », « La veille », « Le jour J ».
  String reminderLead(ReminderLead lead) => switch (lead) {
    ReminderLead.monthBefore => l10n.reminderLeadMonthBefore,
    ReminderLead.weekBefore => l10n.reminderLeadWeekBefore,
    ReminderLead.dayBefore => l10n.reminderLeadDayBefore,
    ReminderLead.sameDay => l10n.reminderLeadSameDay,
  };

  /// Moments d'un rappel dans l'ordre du temps, le jour J toujours compris :
  /// « 7 jours avant · Le jour J ».
  String reminderLeads(Iterable<ReminderLead> leads) => [
    for (final lead in ReminderLead.values)
      if (lead == ReminderLead.sameDay || leads.contains(lead))
        reminderLead(lead),
  ].join(' · ');
}
