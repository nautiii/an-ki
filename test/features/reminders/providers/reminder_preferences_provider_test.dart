import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:an_ki/features/birthday/domain/reminder_lead.dart';
import 'package:an_ki/features/reminders/data/reminder_preferences_repository.dart';
import 'package:an_ki/features/reminders/domain/reminder_preferences.dart';
import 'package:an_ki/features/reminders/providers/reminder_preferences_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_providers.dart';

void main() {
  late RecordingReminderPreferencesRepository repository;

  setUp(() => repository = RecordingReminderPreferencesRepository());

  ProviderContainer makeContainer({String? uid = 'u1'}) {
    final container = ProviderContainer.test(
      retry: (_, _) => null,
      overrides: [
        currentUidProvider.overrideWithValue(uid),
        reminderPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    container.listen(effectiveReminderPreferencesProvider, (_, _) {});
    container.listen(reminderPreferencesEditorProvider, (_, _) {});
    return container;
  }

  group('effective preferences', () {
    test('keep the former cadence out of a session', () async {
      final container = makeContainer(uid: null);
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(effectiveReminderPreferencesProvider),
        const ReminderPreferences(),
      );
    });

    test('fall back to the former cadence when unreadable', () {
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: [
          reminderPreferencesProvider.overrideWithValue(
            AsyncError<ReminderPreferences>(
              Exception('denied'),
              StackTrace.empty,
            ),
          ),
        ],
      );

      expect(
        container.read(effectiveReminderPreferencesProvider),
        const ReminderPreferences(),
      );
    });

    test('are null while loading', () {
      final container = ProviderContainer.test(
        overrides: [
          reminderPreferencesProvider.overrideWithValue(
            const AsyncLoading<ReminderPreferences>(),
          ),
        ],
      );

      expect(container.read(effectiveReminderPreferencesProvider), isNull);
    });
  });

  group('editor', () {
    test('adds then removes a lead, never the day itself', () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);
      final editor = container.read(reminderPreferencesEditorProvider.notifier);

      await editor.toggleLead(ReminderLead.monthBefore);
      await Future<void>.delayed(Duration.zero);
      await editor.toggleLead(ReminderLead.weekBefore);
      await Future<void>.delayed(Duration.zero);
      await editor.toggleLead(ReminderLead.sameDay);

      expect(repository.saved, [
        const ReminderPreferences(
          leads: {
            ReminderLead.monthBefore,
            ReminderLead.weekBefore,
            ReminderLead.sameDay,
          },
        ),
        const ReminderPreferences(
          leads: {ReminderLead.monthBefore, ReminderLead.sameDay},
        ),
      ]);
      expect(container.read(effectiveReminderPreferencesProvider)!.leads, {
        ReminderLead.monthBefore,
        ReminderLead.sameDay,
      });
    });

    test('changes the time, keeping the leads', () async {
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      await container
          .read(reminderPreferencesEditorProvider.notifier)
          .setTime(hour: 7, minute: 45);

      expect(repository.saved, [
        const ReminderPreferences(hour: 7, minute: 45),
      ]);
    });

    test('publishes a failed write', () async {
      repository = RecordingReminderPreferencesRepository(
        failure: Exception('offline'),
      );
      final container = makeContainer();
      await Future<void>.delayed(Duration.zero);

      await container
          .read(reminderPreferencesEditorProvider.notifier)
          .setTime(hour: 7, minute: 45);

      expect(
        container.read(reminderPreferencesEditorProvider).hasError,
        isTrue,
      );
    });

    test('writes nothing out of a session', () async {
      final container = makeContainer(uid: null);
      await Future<void>.delayed(Duration.zero);

      await container
          .read(reminderPreferencesEditorProvider.notifier)
          .toggleLead(ReminderLead.dayBefore);

      expect(repository.saved, isEmpty);
    });
  });
}
