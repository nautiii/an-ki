import 'dart:async';

import 'package:an_ki/core/providers/clock_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Salutation selon l'heure : « Bonjour » le jour, « Bonsoir » le soir.
enum Greeting { day, evening }

/// Première minute du jour (6 h 01), en minutes depuis minuit.
const int greetingDayStartMinute = 6 * 60 + 1;

/// Dernière minute du jour (18 h 00), en minutes depuis minuit : « Bonsoir »
/// commence à la minute suivante et dure jusqu'à 6 h 00 incluse.
const int greetingDayEndMinute = 18 * 60;

/// Salutation de [now], à la minute près.
Greeting greetingAt(DateTime now) {
  final minute = now.hour * 60 + now.minute;
  return minute >= greetingDayStartMinute && minute <= greetingDayEndMinute
      ? Greeting.day
      : Greeting.evening;
}

/// Instant du prochain changement de salutation après [now].
DateTime nextGreetingChange(DateTime now) {
  final minute = now.hour * 60 + now.minute;
  // Heure calendaire : juste les jours de changement d'heure.
  DateTime at(int dayOffset, int minuteOfDay) => DateTime(
    now.year,
    now.month,
    now.day + dayOffset,
    minuteOfDay ~/ 60,
    minuteOfDay % 60,
  );
  if (minute < greetingDayStartMinute) return at(0, greetingDayStartMinute);
  if (minute <= greetingDayEndMinute) return at(0, greetingDayEndMinute + 1);
  return at(1, greetingDayStartMinute);
}

/// Salutation de l'heure courante, recalculée à chaque changement.
///
/// Le minuteur s'annule avec le provider ; un test qui dépend de l'heure la
/// fige avec `clockProvider`.
final greetingProvider = Provider<Greeting>((ref) {
  final now = ref.watch(clockProvider)();
  final timer = Timer(
    nextGreetingChange(now).difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return greetingAt(now);
});
