import 'package:an_ki/features/auth/providers/session_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Vue de l'accueil : l'agenda ou le calendrier.
enum HomeView { agenda, calendar }

/// Vue choisie sur l'accueil, remise à l'agenda quand l'utilisateur change.
class HomeViewNotifier extends Notifier<HomeView> {
  @override
  HomeView build() {
    ref.watch(currentUidProvider);
    return HomeView.agenda;
  }

  void show(HomeView view) => state = view;
}

final homeViewProvider = NotifierProvider<HomeViewNotifier, HomeView>(
  HomeViewNotifier.new,
);
