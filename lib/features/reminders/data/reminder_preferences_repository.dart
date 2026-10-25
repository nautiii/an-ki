import 'package:an_ki/core/providers/firebase_providers.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Réglage par défaut des rappels : le champ `reminders` du profil
/// `user/{uid}` (`{leads: [...], hour, minute}`), qui suit le compte d'un
/// téléphone à l'autre et part avec lui.
///
/// La feature `reminders` ne lit et n'écrit que ce champ : le reste du profil
/// appartient à `user`.
class ReminderPreferencesRepository {
  ReminderPreferencesRepository({required this._firestore});

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _profile(String uid) =>
      _firestore.collection('user').doc(uid);

  /// Réglage de [uid] en temps réel ; celui d'avant B6 tant que rien n'est
  /// enregistré.
  Stream<ReminderPreferences> watchPreferences(String uid) =>
      _profile(uid)
          .snapshots()
          .map((doc) => _preferencesFrom(doc.data()?['reminders']));

  /// Remplace le réglage. `update` et non `set` : sans profil (créé par
  /// `app/bootstrap`), l'écriture échoue au lieu de créer un document qui
  /// passerait pour un profil vide.
  Future<void> savePreferences(String uid, ReminderPreferences preferences) =>
      _profile(uid).update({'reminders': _preferencesToMap(preferences)});
}

final reminderPreferencesRepositoryProvider =
    Provider<ReminderPreferencesRepository>(
      (ref) => ReminderPreferencesRepository(
        firestore: ref.watch(firestoreProvider),
      ),
    );

// Conversion Firestore ↔ domaine. Lecture tolérante : un champ absent ou
// illisible garde la valeur par défaut, un moment inconnu est ignoré.
ReminderPreferences _preferencesFrom(Object? stored) {
  const defaults = ReminderPreferences();
  if (stored is! Map<String, dynamic>) return defaults;
  final names = ReminderLead.values.asNameMap();
  final leads = switch (stored['leads']) {
    final List<dynamic> list => {
      for (final name in list)
        ?names[name],
      ReminderLead.sameDay,
    },
    _ => defaults.leads,
  };
  final hour = switch (stored['hour']) {
    final int hour when hour >= 0 && hour < 24 => hour,
    _ => defaults.hour,
  };
  final minute = switch (stored['minute']) {
    final int minute when minute >= 0 && minute < 60 => minute,
    _ => defaults.minute,
  };
  return ReminderPreferences(leads: leads, hour: hour, minute: minute);
}

Map<String, Object> _preferencesToMap(ReminderPreferences preferences) => {
  'leads': [
    for (final lead in ReminderLead.values)
      if (preferences.leads.contains(lead)) lead.name,
  ],
  'hour': preferences.hour,
  'minute': preferences.minute,
};
