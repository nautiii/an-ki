import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onglets de la coquille, dans l'ordre de la barre du bas.
enum MainTab { birthdays, scanner }

/// Onglet affiché par la coquille : les anniversaires au démarrage et à
/// chaque changement de session.
class NavigationNotifier extends Notifier<MainTab> {
  @override
  MainTab build() {
    ref.watch(currentUidProvider);
    return MainTab.birthdays;
  }

  void setTab(MainTab tab) => state = tab;
}

final navigationProvider = NotifierProvider<NavigationNotifier, MainTab>(
  NavigationNotifier.new,
);
