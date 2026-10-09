import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Horloge de l'application.
///
/// Le code métier (`domain/`) reçoit « maintenant » en paramètre ; les
/// providers le lisent ici. Les tests figent la date avec
/// `clockProvider.overrideWithValue(() => DateTime(2026, 3, 12))`.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Date du jour (à minuit), recalculée quand le jour change.
///
/// Le minuit suivant est calculé en jours calendaires, pas en 24 h, pour
/// rester juste les jours de changement d'heure. Le minuteur s'annule avec le
/// provider, fin d'un `ProviderScope` de test comprise ; un test qui dépend du
/// jour le fige (`todayProvider.overrideWithValue(...)`).
final todayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)();
  final today = DateTime(now.year, now.month, now.day);
  final timer = Timer(
    DateTime(now.year, now.month, now.day + 1).difference(now),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return today;
});
