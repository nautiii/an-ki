import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MainTab { birthdays, scanner }

class NavigationNotifier extends Notifier<MainTab> {
  @override
  MainTab build() => MainTab.birthdays;

  void setTab(MainTab tab) => state = tab;
}

final navigationProvider = NotifierProvider<NavigationNotifier, MainTab>(
  NavigationNotifier.new,
);
