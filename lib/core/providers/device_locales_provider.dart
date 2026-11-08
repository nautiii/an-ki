import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langues préférées du téléphone, dans l'ordre choisi par l'utilisateur :
/// la première est sa langue d'affichage, les suivantes ses langues de
/// secours.
///
/// Lue sans binding Flutter : la tâche de fond s'en sert aussi. `App` relit
/// la liste quand la langue du téléphone change ; les tests la fixent avec
/// `deviceLocalesProvider.overrideWithValue([Locale('fr', 'FR')])`.
final deviceLocalesProvider = Provider<List<Locale>>(
  (ref) => PlatformDispatcher.instance.locales,
);
