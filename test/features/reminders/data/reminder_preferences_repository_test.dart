import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late ReminderPreferencesRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = ReminderPreferencesRepository(firestore: firestore);
  });

  Future<void> seed(String uid, Map<String, dynamic> data) =>
      firestore.collection('user').doc(uid).set(data);

  group('watchPreferences', () {
    test('keeps the former cadence for a profile written before', () async {
      await seed('u1', {'name': 'Léa', 'locale': 'fr'});

      expect(
        await repository.watchPreferences('u1').first,
        const ReminderPreferences(),
      );
    });

    test('keeps the former cadence without a profile', () async {
      expect(
        await repository.watchPreferences('u1').first,
        const ReminderPreferences(),
      );
    });

    test('reads the stored setting, the day itself always in', () async {
      await seed('u1', {
        'reminders': {
          'leads': ['monthBefore', 'dayBefore'],
          'hour': 8,
          'minute': 30,
        },
      });

      expect(
        await repository.watchPreferences('u1').first,
        const ReminderPreferences(
          leads: {
            ReminderLead.monthBefore,
            ReminderLead.dayBefore,
            ReminderLead.sameDay,
          },
          hour: 8,
          minute: 30,
        ),
      );
    });

    test('falls back field by field on what it cannot read', () async {
      await seed('u1', {
        'reminders': {
          'leads': ['hourBefore', 'weekBefore'],
          'hour': 27,
          'minute': '15',
        },
      });

      // Le moment inconnu tombe, l'heure et la minute illisibles aussi : il
      // reste la semaine avant et le jour J, à 10 h.
      expect(
        await repository.watchPreferences('u1').first,
        const ReminderPreferences(),
      );
    });

    test('reads only the profile of the given uid', () async {
      await seed('u2', {
        'reminders': {'leads': <String>[], 'hour': 7, 'minute': 0},
      });
      await seed('u1', {});

      expect(
        await repository.watchPreferences('u1').first,
        const ReminderPreferences(),
      );
    });
  });

  group('savePreferences', () {
    test('writes the setting and leaves the rest of the profile', () async {
      await seed('u1', {'name': 'Léa', 'locale': 'fr'});

      await repository.savePreferences(
        'u1',
        const ReminderPreferences(
          leads: {ReminderLead.sameDay, ReminderLead.dayBefore},
          hour: 9,
          minute: 15,
        ),
      );

      final data = (await firestore.collection('user').doc('u1').get()).data()!;
      expect(data['name'], 'Léa');
      expect(data['reminders'], {
        'leads': ['dayBefore', 'sameDay'],
        'hour': 9,
        'minute': 15,
      });
    });

    test('never creates a profile that does not exist', () async {
      await expectLater(
        repository.savePreferences('u1', const ReminderPreferences()),
        throwsA(anything),
      );

      expect(
        (await firestore.collection('user').doc('u1').get()).exists,
        isFalse,
      );
    });
  });
}
