import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglets de la coquille, dans l'ordre de la barre du bas.
enum MainTab { birthdays, scanner }

/// Onglet affiché par la coquille ; les anniversaires au démarrage.
class NavigationNotifier extends Notifier<MainTab> {
  @override
  MainTab build() => MainTab.birthdays;

  void setTab(MainTab tab) => state = tab;
}

final navigationProvider = NotifierProvider<NavigationNotifier, MainTab>(
  NavigationNotifier.new,
);
