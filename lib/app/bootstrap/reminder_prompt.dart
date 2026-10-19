import 'dart:async';

import 'package:an_ki/core/extensions/localization_extension.dart';
import 'package:an_ki/core/services/notification_service.dart';
import 'package:an_ki/core/theme/app_tokens.dart';
import 'package:an_ki/features/auth/providers/fresh_sign_in_provider.dart';
import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/birthday.dart';
import 'package:an_ki/features/birthday/domain/birthdays_added.dart';
import 'package:an_ki/features/birthday/providers/birthday_additions.dart';
import 'package:an_ki/features/birthday/providers/birthday_provider.dart';
import 'package:an_ki/features/reminders/domain/reminder_offer.dart';
import 'package:an_ki/features/reminders/providers/reminder_permission.dart';
import 'package:an_ki/features/reminders/widgets/reminder_offer_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Propose d'activer les rappels au moment où l'agenda prend de la valeur,
/// jamais au lancement : après un import ou les premiers anniversaires
/// saisis ([reminderOfferAfter]), et quand une connexion retrouve l'agenda
/// d'un compte (nouvel appareil). Au plus une fois par session, et
/// seulement si les notifications ne sont pas accordées.
///
/// La feuille annonce l'ajout qu'elle suit ; sans elle, un import s'annonce
/// ici, par un message. Vit sous la coquille de l'app : chaque connexion
/// ouvre une nouvelle session.
class ReminderPrompt extends ConsumerStatefulWidget {
  const ReminderPrompt({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderPrompt> createState() => _ReminderPromptState();
}

class _ReminderPromptState extends ConsumerState<ReminderPrompt> {
  /// La proposition de la session est faite, ou en route.
  bool _offered = false;

  /// Le premier agenda rempli de la session a été examiné.
  bool _restoreChecked = false;

  /// Import que la feuille doit annoncer : si elle ne s'affiche finalement
  /// pas, le message le fait.
  int? _importToAnnounce;

  Timer? _pending;

  @override
  void initState() {
    super.initState();
    // Lue dès l'ouverture de la session : connue au moment de décider.
    ref.listenManual(reminderPermissionProvider, (_, _) {});
    ref.listenManual(birthdayAdditionsProvider, (_, added) {
      if (added != null) _onAdded(added);
    });
    ref.listenManual(birthdaysProvider, fireImmediately: true, (_, next) {
      if (next case AsyncData(:final value)) _onBirthdays(value);
    });
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }

  void _onAdded(BirthdaysAdded added) {
    final offer = reminderOfferAfter(added);
    if (offer != null && _mayOffer()) {
      _importToAnnounce = added.imported ? added.count : null;
      _schedule(offer);
    } else if (added.imported) {
      _announceImport(added.count);
    }
  }

  /// Agenda d'un compte ouvert par une connexion pendant cette exécution :
  /// ses anniversaires viennent d'arriver sur cet appareil.
  void _onBirthdays(List<Birthday> birthdays) {
    if (_restoreChecked || birthdays.isEmpty) return;
    _restoreChecked = true;
    final uid = ref.read(currentUidProvider);
    if (uid == null || ref.read(freshSignInProvider) != uid) return;
    if (!_mayOffer()) return;
    _schedule(
      ReminderOffer(
        reason: ReminderOfferReason.restored,
        count: birthdays.length,
      ),
    );
  }

  /// Pas encore proposé dans la session, et notifications pas accordées
  /// (ou pas encore lues : la feuille revérifie avant de s'afficher).
  bool _mayOffer() =>
      !_offered &&
      ref.read(reminderPermissionProvider).value != NotificationAccess.granted;

  /// Laisse l'écran d'ajout se fermer et l'agenda se remplir, puis propose.
  /// Une pause, pas une animation : elle vaut aussi sans animations.
  void _schedule(ReminderOffer offer) {
    _offered = true;
    _pending?.cancel();
    _pending = Timer(AppMotion.page, () => unawaited(_show(offer)));
  }

  Future<void> _show(ReminderOffer offer) async {
    // Relue au dernier moment : accordées entre-temps, rien à proposer.
    final access = await ref
        .read(reminderPermissionProvider.notifier)
        .refresh();
    if (!mounted) return;
    final importCount = _importToAnnounce;
    _importToAnnounce = null;
    if (access == NotificationAccess.granted) {
      if (importCount != null) _announceImport(importCount);
      return;
    }
    await ReminderOfferSheet.show(context, offer);
  }

  void _announceImport(int count) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.birthdaysAdded(count))));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
