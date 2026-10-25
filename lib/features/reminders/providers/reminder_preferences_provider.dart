import 'dart:async';

import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Réglage par défaut des rappels de l'utilisateur courant, en temps réel ;
/// celui d'avant B6 hors session.
final reminderPreferencesProvider = StreamProvider<ReminderPreferences>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const ReminderPreferences());
  return ref.watch(reminderPreferencesRepositoryProvider).watchPreferences(uid);
});

/// Réglage qui s'applique : celui de [reminderPreferencesProvider], ou, s'il
/// est illisible, celui d'avant B6 — mieux vaut des rappels qu'aucun. Null
/// tant qu'il se charge.
final effectiveReminderPreferencesProvider = Provider<ReminderPreferences?>((
  ref,
) {
  final preferences = ref.watch(reminderPreferencesProvider);
  if (preferences.hasError && !preferences.hasValue) {
    return const ReminderPreferences();
  }
  return preferences.value;
});

/// Modifications du réglage par défaut (Réglages › Rappels) et état de la
/// dernière : `AsyncLoading` pendant l'écriture, `AsyncError` si elle
/// échoue.
///
/// Écritures optimistes : Firestore met le profil à jour dans son cache tout
/// de suite, le réglage et la replanification suivent sans attendre le
/// serveur.
class ReminderPreferencesEditor extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  /// Ajoute ou retire un rappel avant le jour J ; le jour J reste.
  Future<void> toggleLead(ReminderLead lead) {
    if (lead == ReminderLead.sameDay) return Future.value();
    return _update(
      (preferences) => ReminderPreferences(
        leads: preferences.leads.contains(lead)
            ? ({...preferences.leads}..remove(lead))
            : {...preferences.leads, lead},
        hour: preferences.hour,
        minute: preferences.minute,
      ),
    );
  }

  /// Change l'heure de tous les rappels.
  Future<void> setTime({required int hour, required int minute}) => _update(
    (preferences) => ReminderPreferences(
      leads: preferences.leads,
      hour: hour,
      minute: minute,
    ),
  );

  /// Écrit le réglage modifié ; hors session ou réglage pas encore lu, ne
  /// fait rien.
  Future<void> _update(
    ReminderPreferences Function(ReminderPreferences current) change,
  ) async {
    final uid = ref.read(currentUidProvider);
    final current = ref.read(effectiveReminderPreferencesProvider);
    if (uid == null || current == null) return;
    final repository = ref.read(reminderPreferencesRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => repository.savePreferences(uid, change(current)),
    );
    if (ref.mounted) state = result;
  }
}

final reminderPreferencesEditorProvider =
    AsyncNotifierProvider.autoDispose<ReminderPreferencesEditor, void>(
      ReminderPreferencesEditor.new,
    );
